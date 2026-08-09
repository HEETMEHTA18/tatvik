"""
Tests for MissionPrService — the "Mission → PR" flow in the Command Center.

Covers:
  - Repository understanding (graph + file tree + README)
  - Change planning (LLM returning a JSON plan)
  - PR branch creation, file commits, and proper PR body
  - Graceful degradation without a GitHub token

All external GitHub / LLM calls are mocked; the suite runs fully offline.
"""

import json
import asyncio
import sys
from unittest.mock import AsyncMock, patch, MagicMock

from app.services.mission_pr_service import MissionPrService

_LOOP = None


def _get_loop() -> asyncio.AbstractEventLoop:
    """Reuse a single persistent event loop so asyncio.run() calls do not
    break sibling test suites that rely on asyncio.get_event_loop()."""
    global _LOOP
    if _LOOP is None or _LOOP.is_closed():
        _LOOP = asyncio.new_event_loop()
    try:
        asyncio.set_event_loop(_LOOP)
    except RuntimeError:
        pass
    return _LOOP


def run_async(coro):
    return _get_loop().run_until_complete(coro)


def _gh_response(status: int, payload: dict):
    resp = MagicMock()
    resp.status_code = status
    resp.json.return_value = payload
    resp.text = json.dumps(payload)
    return resp


def test_parse_owner_repo_urls():
    assert MissionPrService._parse_owner_repo("HEETMEHTA18/tatvik") == (
        "HEETMEHTA18",
        "tatvik",
    )
    assert MissionPrService._parse_owner_repo(
        "https://github.com/HEETMEHTA18/tatvik"
    ) == ("HEETMEHTA18", "tatvik")
    assert MissionPrService._parse_owner_repo("not-a-repo") == (None, None)


def test_branch_name_slugified():
    assert MissionPrService._branch_name("Fix: Gemini retry logic!") == (
        "tatvik/mission-fix-gemini-retry-logic"
    )
    assert MissionPrService._branch_name("") == "tatvik/mission"


def test_pr_body_is_professional():
    body = MissionPrService._pr_body(
        mission_title="Add health endpoint",
        mission_description="Expose /health returning status ok",
        changes=["app/main.py"],
        reasoning="The service needs a health check.",
        repo_context="REPOSITORY: owner/repo\nFILE_TREE_SAMPLE: 12 files",
    )
    assert "**Generated autonomously by Tatvik AI OS**" in body
    assert "`app/main.py`" in body
    assert "The service needs a health check." in body
    assert "Add health endpoint" in body


def test_plan_changes_parses_json():
    plan_text = (
        "{\n"
        ' "reasoning": "Add a health endpoint",\n'
        ' "commit_prefix": "feat",\n'
        ' "changes": [\n'
        '   {"path": "backend/app/main.py", "content": "print(\'ok\')"},\n'
        '   {"path": "new_file.md", "content": "# docs"}\n'
        " ]\n"
        "}\n"
    )
    plan = MissionPrService._parse_plan(plan_text)
    assert plan["reasoning"] == "Add a health endpoint"
    assert len(plan["changes"]) == 2
    assert plan["changes"][0]["path"] == "backend/app/main.py"


def test_parse_plan_with_markdown_fences():
    plan = MissionPrService._parse_plan(
        '```json\n{"changes": [{"path": "a.py", "content": "x"}]}\n```'
    )
    assert plan["changes"][0]["path"] == "a.py"


def test_understand_repository_builds_rendered_context():
    service = MissionPrService(github_token="test-token")

    async def fake_get(url, **kwargs):
        if "git/trees" in url:
            payload = {
                "tree": [
                    {"path": "README.md", "type": "blob"},
                    {"path": "app/main.py", "type": "blob"},
                    {"path": "app/models.py", "type": "blob"},
                ]
            }
            return _gh_response(200, payload)
        if "repos" in url and "contents" not in url:
            return _gh_response(200, {"default_branch": "master"})
        if "contents/README.md" in url:
            import base64

            return _gh_response(
                200, {"content": base64.b64encode(b"# My Repo").decode()}
            )
        return _gh_response(404, {})

    async def run_flow():
        service.cognee.enabled = False
        with patch("httpx.AsyncClient") as client_cls:
            client_cls.return_value.__aenter__.return_value.get = fake_get
            return await service.understand_repository("owner/repo", user_id="user-1")

    result = run_async(run_flow())
    assert result["success"] is True
    ctx = result["context"]
    assert ctx["default_branch"] == "master"
    assert ctx["languages"] == ["Python"]
    assert "README.md" in ctx["file_tree"]
    assert "### README.md" in ctx["rendered"]


def test_execute_mission_opens_pr_with_proper_body():
    service = MissionPrService(github_token="test-token")
    import base64 as b64

    async def fake_post(url, headers=None, json=None, timeout=None, **kw):
        if url.endswith("/pulls"):
            return _gh_response(201, {"html_url": "https://github.com/o/r/pull/9"})
        if url.endswith("/git/refs"):
            return _gh_response(201, {})
        return _gh_response(200, {})

    async def fake_get(url, headers=None, params=None, timeout=None, **kw):
        if "git/trees" in url:
            return _gh_response(
                200,
                {"tree": [{"path": "app/main.py", "type": "blob"}]},
            )
        if "repos" in url and "refs" not in url and "contents" not in url:
            return _gh_response(200, {"default_branch": "master"})
        if "contents/app/main.py" in url and params and "sha" in params:
            return _gh_response(
                200, {"content": b64.b64encode(b"old").decode(), "sha": "abc123"}
            )
        if "contents" in url:
            return _gh_response(404, {})
        return _gh_response(200, {"default_branch": "master"})

    async def fake_put(url, headers=None, json=None, timeout=None, **kw):
        return _gh_response(
            200,
            {
                "commit": {"sha": "commitsha123"},
                "content": {"html_url": "https://github.com/o/r/blob/x/app/main.py"},
            },
        )

    plan = {
        "reasoning": "Add a health endpoint",
        "commit_prefix": "feat",
        "changes": [{"path": "app/main.py", "content": "print('ok')\n"}],
    }

    async def run_flow():
        with patch("httpx.AsyncClient") as client_cls:
            client_cls.return_value.__aenter__.return_value.get = fake_get
            client_cls.return_value.__aenter__.return_value.post = fake_post
            client_cls.return_value.__aenter__.return_value.put = fake_put
            with patch.object(
                service, "_plan_changes", new=AsyncMock(return_value=plan)
            ):
                return await service.execute_mission_and_open_pr(
                    repo_full_name="owner/repo",
                    mission_title="Add health endpoint",
                    mission_description="Expose a /health route",
                    user_id="user-1",
                    repo_context="REPOSITORY: owner\nLANGUAGES: Python",
                )

    result = run_async(run_flow())
    assert result["success"] is True
    assert result["pull_request_url"] == "https://github.com/o/r/pull/9"
    assert result["changes_count"] == 1
    assert result["files_changed"] == ["app/main.py"]


def test_execute_mission_without_token_is_graceful():
    service = MissionPrService(github_token="")
    result = run_async(
        service.execute_mission_and_open_pr(
            repo_full_name="owner/repo",
            mission_title="Some mission",
            mission_description="desc",
        )
    )
    assert result["success"] is False
    assert "No GitHub token" in result["error"]


def test_no_changes_needed_short_circuit():
    service = MissionPrService(github_token="test-token")
    plan = {"reasoning": "Nothing to change", "changes": []}

    async def run_flow():
        with patch("httpx.AsyncClient"), patch.object(
            service, "_plan_changes", new=AsyncMock(return_value=plan)
        ):
            return await service.execute_mission_and_open_pr(
                repo_full_name="owner/repo",
                mission_title="Docs only",
                mission_description="Nothing",
                repo_context="REPOSITORY: owner/repo",
            )

    result = run_async(run_flow())
    assert result["success"] is True
    assert result["no_changes_needed"] is True
