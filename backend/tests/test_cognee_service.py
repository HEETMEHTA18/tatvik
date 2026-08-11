import asyncio
from unittest.mock import AsyncMock, MagicMock, patch

from app.services.cognee_service import CogneeService

_LOOP = None


def _get_loop() -> asyncio.AbstractEventLoop:
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


class TestRecallParsing:
    def test_graph_entries_extract_text(self):
        data = [
            {
                "source": "graph",
                "text": "FastAPI backend with async endpoints",
                "score": 0.9,
            },
            {"source": "graph", "text": "", "score": 0.5},
        ]
        assert CogneeService._parse_recall_results(data) == [
            "FastAPI backend with async endpoints"
        ]

    def test_session_qa_entries_extract_answer(self):
        data = [
            {
                "source": "session",
                "question": "q",
                "context": "ctx",
                "answer": "the answer",
            }
        ]
        assert CogneeService._parse_recall_results(data) == ["the answer"]

    def test_session_context_entries_extract_content(self):
        data = [{"source": "session_context", "content": "remembered detail"}]
        assert CogneeService._parse_recall_results(data) == ["remembered detail"]

    def test_raw_fallback(self):
        data = [{"source": "graph", "text": "", "raw": {"text": "raw text"}}]
        assert CogneeService._parse_recall_results(data) == ["raw text"]

    def test_non_dict_entries_coerced(self):
        data = ["plain string entry"]
        assert CogneeService._parse_recall_results(data) == ["plain string entry"]

    def test_empty_and_blank_entries_dropped(self):
        assert CogneeService._parse_recall_results([]) == []
        assert CogneeService._parse_recall_results(None) == []
        assert (
            CogneeService._parse_recall_results([{"source": "graph", "text": "   "}])
            == []
        )


class TestStoreText:
    def test_stub_mode_returns_true_without_http(self):
        service = CogneeService()
        service.enabled = False
        assert run_async(service._store_text("topic", "content")) is True

    def test_store_sends_remember_with_dataset_and_background(self):
        service = CogneeService()
        service.enabled = True
        resp = MagicMock()
        resp.status_code = 200

        with patch("app.services.cognee_service.httpx.AsyncClient") as mock_client:
            instance = mock_client.return_value
            instance.__aenter__ = AsyncMock(return_value=instance)
            instance.post = AsyncMock(return_value=resp)
            result = run_async(service._store_text("my_topic", "hello world"))

        assert result is True
        args, kwargs = instance.post.await_args
        assert args[0] == f"{service.base_url}/api/v1/remember"
        assert kwargs["headers"] == {"X-Api-Key": service.api_key}
        form_data = kwargs["data"]
        assert form_data["datasetName"] == service.brain_name
        assert form_data["run_in_background"] == "true"
        files = kwargs["files"]
        assert "data" in files
        assert files["data"][0] == "my_topic.txt"

    def test_store_failure_logs_and_returns_false(self):
        service = CogneeService()
        service.enabled = True
        resp = MagicMock()
        resp.status_code = 500
        resp.text = "boom"

        with patch("app.services.cognee_service.httpx.AsyncClient") as mock_client:
            instance = mock_client.return_value
            instance.__aenter__ = AsyncMock(return_value=instance)
            instance.post = AsyncMock(return_value=resp)
            result = run_async(service._store_text("my_topic", "hello"))

        assert result is False


class TestRecall:
    def test_recall_scopes_to_brain_dataset_and_parses(self):
        service = CogneeService()
        service.enabled = True
        resp = MagicMock()
        resp.status_code = 200
        resp.json.return_value = [
            {"source": "graph", "text": "graph answer"},
            {"source": "graph", "text": "second chunk"},
        ]

        with patch("app.services.cognee_service.httpx.AsyncClient") as mock_client:
            instance = mock_client.return_value
            instance.__aenter__ = AsyncMock(return_value=instance)
            instance.post = AsyncMock(return_value=resp)
            results = run_async(
                service.query_repository_memory("user1", "owner/repo", "what stack?")
            )

        assert results == ["graph answer", "second chunk"]
        _, kwargs = instance.post.await_args
        payload = kwargs["json"]
        assert payload["datasets"] == [service.brain_name]
        assert payload["search_type"] == "HYBRID_COMPLETION"

    def test_recall_error_returns_empty(self):
        service = CogneeService()
        service.enabled = True
        resp = MagicMock()
        resp.status_code = 403
        resp.text = "no permission"

        with patch("app.services.cognee_service.httpx.AsyncClient") as mock_client:
            instance = mock_client.return_value
            instance.__aenter__ = AsyncMock(return_value=instance)
            instance.post = AsyncMock(return_value=resp)
            results = run_async(service.ask_codebase("user1", "where is auth?"))

        assert results == "No results found for your question."

    def test_ask_codebase_joins_multiple_results(self):
        service = CogneeService()
        service.enabled = True
        resp = MagicMock()
        resp.status_code = 200
        resp.json.return_value = [
            {"source": "graph", "text": "part one"},
            {"source": "graph", "text": "part two"},
        ]

        with patch("app.services.cognee_service.httpx.AsyncClient") as mock_client:
            instance = mock_client.return_value
            instance.__aenter__ = AsyncMock(return_value=instance)
            instance.post = AsyncMock(return_value=resp)
            answer = run_async(service.ask_codebase("user1", "architecture?"))

        assert answer == "part one\n\npart two"


class TestHealthCheck:
    def test_health_stub_mode(self):
        service = CogneeService()
        service.enabled = False
        result = run_async(service.check_health())
        assert result["enabled"] is False
        assert result["reachable"] is False

    def test_health_ok(self):
        service = CogneeService()
        service.enabled = True
        health_resp = MagicMock()
        health_resp.status_code = 200
        datasets_resp = MagicMock()
        datasets_resp.status_code = 200

        with patch("app.services.cognee_service.httpx.AsyncClient") as mock_client:
            instance = mock_client.return_value
            instance.__aenter__ = AsyncMock(return_value=instance)
            instance.get = AsyncMock(side_effect=[health_resp, datasets_resp])
            result = run_async(service.check_health())

        assert result["reachable"] is True
        assert result["auth_valid"] is True

    def test_health_bad_url_or_key(self):
        service = CogneeService()
        service.enabled = True
        health_resp = MagicMock()
        health_resp.status_code = 404
        datasets_resp = MagicMock()
        datasets_resp.status_code = 404

        with patch("app.services.cognee_service.httpx.AsyncClient") as mock_client:
            instance = mock_client.return_value
            instance.__aenter__ = AsyncMock(return_value=instance)
            instance.get = AsyncMock(side_effect=[health_resp, datasets_resp])
            result = run_async(service.check_health())

        assert result["reachable"] is False
        assert result["auth_valid"] is False
