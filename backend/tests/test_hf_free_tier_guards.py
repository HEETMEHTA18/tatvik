"""
HF free-tier protection + developer skills — tests
===================================================
Covers the changes added to keep the HuggingFace OpenClaw gateway (and the
Gemini free-tier quota) from being exhausted by command-center missions:

  1. OpenClaw bootstrap-reply detection (fail fast on "Who am I?" answers).
  2. Batched stage output splitting (fewer gateway dispatches).
  3. Gemini circuit breaker / rate-guard behavior.
  4. Developer skills registry (AutoDevs + skills.sh) and stack detection.
"""

import asyncio
from unittest.mock import AsyncMock, patch

from app.api.v1.endpoints import openclaw as openclaw_endpoint
from app.services.openclaw_service import OpenClawService
from app.services import developer_skills

# ── 1. Bootstrap detection ────────────────────────────────────────────────────


def test_bootstrap_reply_is_detected():
    assert (
        OpenClawService._looks_like_bootstrap(
            "Hey. I just came online. Who am I? Who are you?"
        )
        is True
    )
    assert (
        OpenClawService._looks_like_bootstrap(
            "Hey there! I just came online. Before we dive into plans..."
        )
        is True
    )


def test_normal_answer_is_not_bootstrap():
    assert (
        OpenClawService._looks_like_bootstrap(
            "Here are the functional requirements: 1) capture output, 2) verify."
        )
        is False
    )
    # Long legitimate replies are never misclassified.
    assert OpenClawService._looks_like_bootstrap("ok " * 300) is False


def test_dispatch_rejects_bootstrap_output():
    service = OpenClawService()
    service.enabled = True
    payload = {
        "choices": [{"message": {"content": "Hey. I just came online. Who am I?"}}]
    }
    resp = _resp(200, payload)
    with patch("httpx.AsyncClient.post", new=AsyncMock(return_value=resp)):
        result = asyncio.run(service.generate("some prompt"))
    assert result["success"] is False
    assert "bootstrap" in result["error"].lower()


def test_dispatch_accepts_real_output():
    service = OpenClawService()
    service.enabled = True
    payload = {"choices": [{"message": {"content": '{"planning": "build a router"}'}}]}
    resp = _resp(200, payload)
    with patch("httpx.AsyncClient.post", new=AsyncMock(return_value=resp)):
        result = asyncio.run(service.generate("some prompt"))
    assert result["success"] is True
    assert result["output"] == '{"planning": "build a router"}'


# ── 2. Batched stage splitting ────────────────────────────────────────────────


def test_split_batch_output_json():
    text = '{"requirement": "reqs", "planning": "plan", "design": "design"}'
    split = openclaw_endpoint._split_batch_output(
        text, ["requirement", "planning", "design"]
    )
    assert split == {"requirement": "reqs", "planning": "plan", "design": "design"}


def test_split_batch_output_markdown_fenced():
    text = '```json\n{"development": "code it"}\n```'
    split = openclaw_endpoint._split_batch_output(text, ["development"])
    assert split == {"development": "code it"}


def test_split_batch_output_unparseable_returns_none():
    assert openclaw_endpoint._split_batch_output("", ["requirement"]) is None
    assert (
        openclaw_endpoint._split_batch_output(
            "I think we should refactor the API layer.", ["requirement"]
        )
        is None
    )


def test_split_batch_output_missing_key_returns_none():
    # JSON parses but no requested key is present -> caller falls back.
    assert (
        openclaw_endpoint._split_batch_output('{"other": "x"}', ["requirement"]) is None
    )


# ── 3. Gemini circuit breaker ─────────────────────────────────────────────────


def test_circuit_breaker_trips_and_recovers():
    from app.api.v1.endpoints.research import _GeminiRateGuard

    guard = _GeminiRateGuard()
    threshold = int(
        getattr(
            __import__("app.core.config", fromlist=["settings"]).settings,
            "gemini_circuit_threshold",
            3,
        )
    )
    assert guard.is_open() is False
    for _ in range(threshold):
        guard.record_error(429)
    assert guard.is_open() is True
    # Cool-down reset path: simulate expiry.
    guard._open_until = 0.0
    assert guard.is_open() is False


def test_rate_guard_release_after_acquire():
    from app.api.v1.endpoints.research import _GeminiRateGuard

    guard = _GeminiRateGuard()

    async def _exercise():
        await guard.acquire()
        guard.release()
        # Second acquire must succeed (semaphore released).
        await guard.acquire()
        guard.release()

    asyncio.run(_exercise())


# ── 4. Developer skills registry ──────────────────────────────────────────────


def test_detect_stack_flutter_fastapi():
    langs = ["Python", "Dart"]
    tree = [
        "backend/app/main.py",
        "backend/tests/test_api.py",
        "lib/main.dart",
        "pubspec.yaml",
    ]
    stack = developer_skills.detect_stack(langs, tree)
    assert "flutter-best-practices" in stack["frontend"]
    assert "fastapi-rest" in stack["backend"]
    assert "tdd" in stack["backend"]


def test_build_skills_context_includes_rules():
    ctx = developer_skills.build_skills_context(
        ["Python", "Dart"], ["lib/main.dart", "backend/app/main.py"]
    )
    assert "DEVELOPER SKILLS TO APPLY" in ctx
    assert "fastapi-rest" in ctx or "flutter-best-practices" in ctx


def test_build_skills_context_cross_cutting_for_unknown_stack():
    # Cross-cutting skills (code-review, diagnosing-bugs) always apply even for
    # an unrecognized stack, so the block is never empty.
    ctx = developer_skills.build_skills_context(["Brainfuck"], ["x.bf"])
    assert "DEVELOPER SKILLS TO APPLY" in ctx
    assert "code-review" in ctx


def test_load_autodev_prompts():
    # The repo ships .autodevs/prompts.md at the root.
    text = developer_skills.load_autodev_prompts()
    assert isinstance(text, str)
    if text:
        assert "tatvik" in text.lower() or "prompt" in text.lower()


def test_skills_registry_shape():
    reg = developer_skills.skills_registry()
    assert isinstance(reg["profiles"], list)
    assert any(s["id"] == "fastapi-rest" for s in reg["backend"])
    assert any(s["id"] == "frontend-design" for s in reg["frontend"])


# ── helpers ───────────────────────────────────────────────────────────────────


def _resp(status: int, payload: dict):
    from unittest.mock import MagicMock

    resp = MagicMock()
    resp.status_code = status
    resp.json.return_value = payload
    resp.text = str(payload)
    return resp
