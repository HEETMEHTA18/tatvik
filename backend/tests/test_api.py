from fastapi.testclient import TestClient
from sqlalchemy.orm import Session
from app.db.base import Base
from app.db.session import engine, get_db
from app.main import app
from app.models.entities import (
    PromptHistory,
    AutoDevSession,
    ExecutedCommand,
    GeneratedFile,
)

client = TestClient(app)


def setup_module():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)


def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_register_and_login_flow():
    register_response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "devmentor@example.com",
            "password": "Password123!",
            "name": "Dev Mentor",
        },
    )
    assert register_response.status_code == 200
    assert "access_token" in register_response.json()

    login_response = client.post(
        "/api/v1/auth/login",
        json={"email": "devmentor@example.com", "password": "Password123!"},
    )
    assert login_response.status_code == 200
    assert "access_token" in login_response.json()


def get_auth_headers():
    login_response = client.post(
        "/api/v1/auth/login",
        json={"email": "devmentor@gmail.com", "password": "Password123!"},
    )
    token = login_response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_legacy_prompt_event():
    headers = get_auth_headers()
    response = client.post(
        "/api/v1/prompts/event",
        json={
            "original_prompt": "Create a React component",
            "project_name": "my-project",
            "file_context": "index.js",
        },
        headers=headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["original_prompt"] == "Create a React component"
    assert data["project_name"] == "my-project"
    assert "refined_prompt" in data
    assert "score" in data


def test_autodev_session_telemetry_flow():
    headers = get_auth_headers()

    # 1. Session Start
    session_id = "test-session-123"
    response = client.post(
        "/api/v1/prompts/event",
        json={
            "event": "session.started",
            "session_id": session_id,
            "timestamp": "2026-06-06T12:00:00Z",
            "data": {
                "session_id": session_id,
                "start_time": "2026-06-06T12:00:00Z",
                "metadata": {
                    "project_name": "my-go-project",
                    "path": "/path/to/go-project",
                    "branch": "main",
                    "commit": "abc12345",
                    "languages": ["Go", "HTML"],
                    "frameworks": [],
                },
            },
        },
        headers=headers,
    )
    assert response.status_code == 200
    assert response.json()["success"] is True

    # 2. Prompt Captured with Commands and Files
    response = client.post(
        "/api/v1/prompts/event",
        json={
            "event": "prompt.captured",
            "session_id": session_id,
            "timestamp": "2026-06-06T12:01:00Z",
            "data": {
                "id": "prompt-evt-1",
                "timestamp": "2026-06-06T12:01:00Z",
                "prompt": "write a go function to add two numbers",
                "response": "func Add(a, b int) int { return a + b }",
                "executed_commands": [
                    {
                        "command": "go test",
                        "args": ["./..."],
                        "exit_code": 0,
                        "stdout": "PASS",
                        "stderr": "",
                        "duration_ms": 150,
                        "timestamp": "2026-06-06T12:01:05Z",
                    }
                ],
                "generated_files": [
                    {
                        "file_path": "math.go",
                        "size_bytes": 120,
                        "action": "created",
                        "timestamp": "2026-06-06T12:01:10Z",
                    }
                ],
                "metadata": {
                    "project_name": "my-go-project",
                    "path": "/path/to/go-project",
                    "branch": "main",
                    "commit": "abc12345",
                    "languages": ["Go"],
                    "frameworks": [],
                },
            },
        },
        headers=headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["original_prompt"] == "write a go function to add two numbers"
    assert "refined_prompt" in data
    assert "score" in data

    # 3. Session End
    response = client.post(
        "/api/v1/prompts/event",
        json={
            "event": "session.ended",
            "session_id": session_id,
            "timestamp": "2026-06-06T12:05:00Z",
            "data": {
                "session_id": session_id,
                "start_time": "2026-06-06T12:00:00Z",
                "end_time": "2026-06-06T12:05:00Z",
                "metadata": {
                    "project_name": "my-go-project",
                    "path": "/path/to/go-project",
                },
            },
        },
        headers=headers,
    )
    assert response.status_code == 200
    assert response.json()["success"] is True

    # Validate database records manually
    db = next(get_db())
    db_session = db.query(AutoDevSession).filter_by(session_id=session_id).first()
    assert db_session is not None
    assert db_session.project_name == "my-go-project"
    assert db_session.languages == "Go, HTML"
    assert db_session.end_time is not None

    db_prompt = db.query(PromptHistory).filter_by(session_id=session_id).first()
    assert db_prompt is not None
    assert db_prompt.prompt_id == "prompt-evt-1"
    assert db_prompt.original_prompt == "write a go function to add two numbers"
    assert db_prompt.response == "func Add(a, b int) int { return a + b }"

    db_cmd = db.query(ExecutedCommand).filter_by(session_id=session_id).first()
    assert db_cmd is not None
    assert db_cmd.command == "go test"
    assert db_cmd.prompt_event_id == db_prompt.id

    db_file = db.query(GeneratedFile).filter_by(session_id=session_id).first()
    assert db_file is not None
    assert db_file.file_path == "math.go"
    assert db_file.prompt_event_id == db_prompt.id
