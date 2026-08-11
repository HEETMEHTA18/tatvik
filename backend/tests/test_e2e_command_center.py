"""
Tatvik Command Center — End-to-End Test
=======================================
Exercises the full command-center flow that the Flutter UI drives:

    Auth (register/login)
      → UI repo list (GET /github/repositories)          [dropdown source]
      → Create mission (POST /openclaw/missions)         [Run button]
      → Execute capability (POST /openclaw/execute)      [tool dispatch]
      → Verify DB persistence                            [prompt_histories + executed_commands]
      → Verify mission (POST /openclaw/missions/complete)

Runs against an isolated SQLite test DB (set in conftest.py).
The OpenClaw engine runs in dry-run/stub mode, so it is safe for CI.
"""

import json
from sqlalchemy import select
from fastapi.testclient import TestClient

from app.db.base import Base
from app.db.session import engine, SessionLocal
from app.main import app
from app.models.entities import PromptHistory, ExecutedCommand

client = TestClient(app)

EMAIL = "e2e-command-center@example.com"
PASSWORD = "Password123!"


def setup_module():
    """Create a clean schema for the e2e run."""
    try:
        Base.metadata.drop_all(bind=engine)
    except Exception:
        pass
    Base.metadata.create_all(bind=engine)
    import app.api.v1.endpoints.research as research

    research.redis_client = None


def test_command_center_e2e_flow():
    headers = _setup_user()
    user_id = _extract_user_id(headers)

    # ── 1. UI layer: repository list that populates the Command Center dropdown ──
    repos_resp = client.get("/api/v1/github/repositories", headers=headers)
    assert repos_resp.status_code == 200, repos_resp.text
    repo_items = repos_resp.json().get("items", [])
    assert isinstance(repo_items, list)
    # The UI must be handed a usable repo (full_name) to target.
    if repo_items:
        assert repo_items[0]["full_name"]
    target_repo = repo_items[0]["full_name"] if repo_items else "HEETMEHTA18/tatvik"

    # ── 2. UI "Run" → create + execute a mission ──
    create_resp = client.post(
        "/api/v1/openclaw/missions",
        json={
            "title": "E2E Mission: wire command center",
            "description": "Verify UI → backend → DB flow",
            "priority": "medium",
            "repository": f"https://github.com/{target_repo}",
            "execute": True,
        },
        headers=headers,
    )
    assert create_resp.status_code == 200, create_resp.text
    mission = create_resp.json()["mission"]
    assert mission["title"] == "E2E Mission: wire command center"
    assert create_resp.json().get("execution_started") is True

    # ── 3. Execute an actual tool capability (dry-run engine in CI) ──
    exec_resp = client.post(
        "/api/v1/openclaw/execute",
        json={
            "tool_id": "github",
            "capability": "search_issues",
            "parameters": {"repo": target_repo, "query": "bug"},
        },
        headers=headers,
    )
    assert exec_resp.status_code == 200, exec_resp.text
    assert exec_resp.json()["tool_id"] == "github"
    assert exec_resp.json()["capability"] == "search_issues"

    # ── 4. Verify the run was persisted to the DB (logs/history) ─────────────
    db = SessionLocal()
    try:
        histories = db.scalars(
            select(PromptHistory).where(PromptHistory.user_id == user_id)
        ).all()
        assert histories, "Expected at least one PromptHistory row from the execution"

        commands = db.scalars(select(ExecutedCommand)).all()
        cmd = next((c for c in commands if c.command == "github.search_issues"), None)
        assert (
            cmd is not None
        ), "expected an ExecutedCommand row for github.search_issues"
        assert cmd.args is not None
        assert isinstance(json.loads(cmd.args), dict), "args must be a JSON dict"
    finally:
        db.close()

    # ── 5. Pipeline status reflects the working mission ────────────────────
    status_resp = client.get("/api/v1/openclaw/pipeline/status", headers=headers)
    assert status_resp.status_code == 200, status_resp.text
    pipeline = status_resp.json().get("pipeline", {})
    assert (
        pipeline.get("mission", {}).get("title") == "E2E Mission: wire command center"
    )

    # ── 6. Complete the mission → stored to memory ──────────────────────────
    complete_resp = client.post("/api/v1/openclaw/missions/complete", headers=headers)
    assert complete_resp.status_code == 200, complete_resp.text
    assert complete_resp.json()["success"] is True


def _setup_user():
    resp = client.post(
        "/api/v1/auth/register",
        json={"email": EMAIL, "password": PASSWORD, "name": "E2E User"},
    )
    if resp.status_code == 409 or "already" in resp.text.lower():
        pass
    else:
        assert resp.status_code == 200, resp.text

    login = client.post(
        "/api/v1/auth/login",
        json={"email": EMAIL, "password": PASSWORD},
    )
    assert login.status_code == 200, login.text
    token = login.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def _extract_user_id(headers):
    from jose import jwt
    from app.core.config import settings

    token = headers["Authorization"].replace("Bearer ", "")
    payload = jwt.decode(
        token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm]
    )
    return str(payload.get("sub"))
