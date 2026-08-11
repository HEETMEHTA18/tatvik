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
    try:
        Base.metadata.drop_all(bind=engine)
    except Exception:
        pass
    Base.metadata.create_all(bind=engine)
    import app.api.v1.endpoints.research as research

    research.redis_client = None


def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_register_and_login_flow():
    register_response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "tatvik@example.com",
            "password": "Password123!",
            "name": "Dev Mentor",
        },
    )
    assert register_response.status_code == 200
    assert "access_token" in register_response.json()

    login_response = client.post(
        "/api/v1/auth/login",
        json={"email": "tatvik@example.com", "password": "Password123!"},
    )
    assert login_response.status_code == 200
    assert "access_token" in login_response.json()


def get_auth_headers():
    login_response = client.post(
        "/api/v1/auth/login",
        json={"email": "tatvik@example.com", "password": "Password123!"},
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


def test_research_github_search():
    headers = get_auth_headers()
    from unittest.mock import patch, MagicMock

    with patch("httpx.AsyncClient.get") as mock_get, patch(
        "app.api.v1.endpoints.research.call_gemini"
    ) as mock_gemini:
        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: {
                "items": [
                    {
                        "full_name": "test/repo",
                        "description": "Test description",
                        "stargazers_count": 5,
                        "html_url": "https://github.com/test/repo",
                    }
                ]
            },
        )
        mock_gemini.return_value = "AI analysis summary"

        response = client.post(
            "/api/v1/research/github",
            json={"query": "test query"},
            headers=headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["platform"] == "github"
        assert data["query"] == "test query"
        assert len(data["results"]) == 1
        assert data["summary"] == "AI analysis summary"


def test_research_github_url():
    headers = get_auth_headers()
    from unittest.mock import patch, MagicMock

    with patch("httpx.AsyncClient.get") as mock_get, patch(
        "app.api.v1.endpoints.research.call_gemini"
    ) as mock_gemini:
        mock_get.return_value = MagicMock(
            status_code=200, text="Mock scraped repo contents"
        )
        mock_gemini.return_value = "AI repo summary"

        response = client.post(
            "/api/v1/research/github",
            json={"url": "https://github.com/test/repo"},
            headers=headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["platform"] == "github"
        assert data["url"] == "https://github.com/test/repo"
        assert data["summary"] == "AI repo summary"


def test_research_youtube():
    headers = get_auth_headers()
    from unittest.mock import patch, MagicMock

    with patch("yt_dlp.YoutubeDL") as mock_ydl, patch(
        "app.api.v1.endpoints.research.call_gemini"
    ) as mock_gemini, patch("os.path.exists", return_value=True), patch(
        "builtins.open", create=True
    ) as mock_open:
        mock_ydl_instance = MagicMock()
        mock_ydl.return_value.__enter__.return_value = mock_ydl_instance
        mock_ydl_instance.extract_info.return_value = {
            "title": "Test Title",
            "description": "Test Desc",
        }
        mock_gemini.return_value = "AI youtube summary"
        mock_open.return_value.__enter__.return_value.read.return_value = (
            "WEBVTT\n\n00:00:00.000 --> 00:00:05.000\nHello YouTube"
        )

        response = client.post(
            "/api/v1/research/youtube",
            json={"url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"},
            headers=headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["platform"] == "youtube"
        assert data["summary"] == "AI youtube summary"


def test_research_reddit():
    headers = get_auth_headers()
    from unittest.mock import patch, MagicMock

    with patch("httpx.AsyncClient.get") as mock_get, patch(
        "app.api.v1.endpoints.research.call_gemini"
    ) as mock_gemini:
        mock_get.return_value = MagicMock(
            status_code=200, text="Mock scraped Reddit contents"
        )
        mock_gemini.return_value = "AI reddit summary"

        response = client.post(
            "/api/v1/research/reddit",
            json={"query": "test query"},
            headers=headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["platform"] == "reddit"
        assert data["query"] == "test query"
        assert data["summary"] == "AI reddit summary"


def test_research_rss():
    headers = get_auth_headers()
    from unittest.mock import patch, MagicMock

    with patch("feedparser.parse") as mock_parse, patch(
        "app.api.v1.endpoints.research.call_gemini"
    ) as mock_gemini:
        mock_entry = MagicMock()
        mock_entry.get.side_effect = lambda k, default=None: {
            "title": "Test Feed Entry",
            "link": "https://example.com/entry",
            "published": "2026-06-19",
            "summary": "Sample summary",
        }.get(k, default)
        mock_parse.return_value = MagicMock(entries=[mock_entry])
        mock_gemini.return_value = "AI rss summary"

        response = client.post(
            "/api/v1/research/rss",
            json={"url": "https://example.com/rss.xml"},
            headers=headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["platform"] == "rss"
        assert data["url"] == "https://example.com/rss.xml"
        assert data["summary"] == "AI rss summary"


def test_research_project_analysis():
    headers = get_auth_headers()
    from unittest.mock import patch, MagicMock

    with patch("httpx.AsyncClient.get") as mock_get, patch(
        "app.api.v1.endpoints.research.call_gemini"
    ) as mock_gemini:
        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: {
                "items": [
                    {
                        "full_name": "test/repo",
                        "description": "Test description",
                        "stargazers_count": 5,
                        "html_url": "https://github.com/test/repo",
                    }
                ]
            },
        )
        mock_gemini.return_value = "AI project plan"

        response = client.post(
            "/api/v1/research/project-analysis",
            json={"project_idea": "SaaS Platform"},
            headers=headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert "roadmap_id" in data
        assert "analysis" in data
        assert data["analysis"] == "AI project plan"


def test_research_learning_path():
    headers = get_auth_headers()
    from unittest.mock import patch, MagicMock

    with patch("httpx.AsyncClient.get") as mock_get, patch(
        "app.api.v1.endpoints.research.call_gemini"
    ) as mock_gemini:
        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: {
                "items": [
                    {
                        "full_name": "test/repo",
                        "description": "Test description",
                        "stargazers_count": 5,
                        "html_url": "https://github.com/test/repo",
                    }
                ]
            },
        )
        mock_gemini.return_value = "AI learning guide"

        response = client.post(
            "/api/v1/research/learning-path",
            json={"role": "Python Developer", "target_technologies": ["FastAPI"]},
            headers=headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert "roadmap_id" in data
        assert "learning_path" in data
        assert data["learning_path"] == "AI learning guide"


def test_research_digest():
    headers = get_auth_headers()
    from unittest.mock import patch, MagicMock

    with patch("feedparser.parse") as mock_parse, patch(
        "app.api.v1.endpoints.research.call_gemini"
    ) as mock_gemini:
        mock_parse.return_value = MagicMock(entries=[])
        mock_gemini.return_value = "AI general updates digest"

        response = client.get(
            "/api/v1/research/digest?topic=general",
            headers=headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["topic"] == "general"
        assert data["digest"] == "AI general updates digest"


def test_refine_prompt_endpoint():
    headers = get_auth_headers()
    from unittest.mock import patch

    # 1. Create a prompt history entry first
    event_response = client.post(
        "/api/v1/prompts/event",
        json={
            "original_prompt": "Optimize this database query select count from table",
            "project_name": "db-opt",
        },
        headers=headers,
    )
    if event_response.status_code != 200:
        print("ERROR BODY:", event_response.json())
    assert event_response.status_code == 200
    prompt_data = event_response.json()
    prompt_id = prompt_data["id"]
    assert prompt_data["refined_prompt"] == ""
    assert prompt_data["score"] == 0

    # 2. Call the refine endpoint with mocked call_ai_json
    with patch("app.api.v1.endpoints.prompts.call_ai_json") as mock_call:
        mock_call.return_value = {
            "refined_prompt": "Use indexed subquery or COUNT(1) to avoid sequential scan.",
            "score": 85,
            "technologies": ["PostgreSQL", "SQL"],
            "workflow": "Database",
        }

        refine_response = client.post(
            f"/api/v1/prompts/{prompt_id}/refine",
            headers=headers,
        )
        assert refine_response.status_code == 200
        res_data = refine_response.json()
        assert "refined_prompt" in res_data
        assert res_data["score"] == 85
        assert "PostgreSQL" in res_data["technologies"]

    # 3. Retrieve prompt detail to verify it is persisted
    history_response = client.get(
        "/api/v1/prompts/history",
        headers=headers,
    )
    assert history_response.status_code == 200
    history_list = history_response.json()
    assertMatched = [p for p in history_list if p["id"] == prompt_id]
    assert len(assertMatched) == 1
    assert (
        assertMatched[0]["refined_prompt"]
        == "Use indexed subquery or COUNT(1) to avoid sequential scan."
    )
    assert assertMatched[0]["score"] == 85


def test_mentor_chat_repository_targeting():
    headers = get_auth_headers()
    from unittest.mock import patch, AsyncMock

    with patch("app.api.v1.endpoints.mentor.GithubAgentService") as mock_agent_class:
        mock_agent_instance = mock_agent_class.return_value
        mock_agent_instance.execute_task_and_pr = AsyncMock(
            return_value={
                "pull_request_url": "https://github.com/test-owner/test-repo/pull/1"
            }
        )

        response = client.post(
            "/api/v1/mentor/chat",
            json={
                "message": "implement this feature in test-owner/test-repo",
                "resume_context": None,
                "history": [],
            },
            headers=headers,
        )

        assert response.status_code == 200
        mock_agent_instance.execute_task_and_pr.assert_called_once()
        args, kwargs = mock_agent_instance.execute_task_and_pr.call_args
        assert kwargs.get("repo_full_name") == "test-owner/test-repo"
