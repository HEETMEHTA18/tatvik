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


def test_parse_plan_marks_ai_unavailable_on_empty_input():
    plan = MissionPrService._parse_plan("")
    assert plan["ai_unavailable"] is True
    assert plan["changes"] == []


def test_parse_plan_marks_ai_unavailable_on_error_sentinel():
    plan = MissionPrService._parse_plan("Error: AI service unavailable after retries.")
    assert plan["ai_unavailable"] is True


def test_parse_plan_marks_ai_unavailable_on_unparseable_prose():
    plan = MissionPrService._parse_plan("I think we should refactor the API layer.")
    assert plan["ai_unavailable"] is True


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


def test_ai_unavailable_marks_mission_failed():
    """When no AI provider can answer, the mission must not be reported as a
    clean no-op — it fails loudly so the user knows the pipeline needs
    credentials/quota restored."""
    service = MissionPrService(github_token="test-token")
    plan = {"reasoning": "", "changes": [], "ai_unavailable": True}

    async def run_flow():
        with patch("httpx.AsyncClient"), patch.object(
            service, "_plan_changes", new=AsyncMock(return_value=plan)
        ):
            return await service.execute_mission_and_open_pr(
                repo_full_name="owner/repo",
                mission_title="Analyze repo",
                mission_description="desc",
                repo_context="REPOSITORY: owner/repo",
            )

    result = run_async(run_flow())
    assert result["success"] is False
    assert "No AI provider" in result["error"]


# ──────────────────────────────────────────────
# FULL COMMAND-CENTER MISSION → PR FLOW
# ──────────────────────────────────────────────
#
# These mirror what the Command Center / UI sends and verify the whole path:
#   mission (title + description + priority + repository) → repo understood
#   via the graph → significant changes planned → feature branch → PR opened
#   → PR URL recorded in the pipeline snapshot.


def _fake_understand_success(repo_full_name, user_id=""):
    return {
        "success": True,
        "context": {
            "default_branch": "master",
            "file_tree": ["backend/app/main.py"],
            "graph_context": "matched graph memory",
            "rendered": (
                f"REPOSITORY: {repo_full_name}\n"
                "LANGUAGES: Python\n"
                "FILE_TREE_SAMPLE (4 files):\n"
                "  - backend/app/main.py"
            ),
        },
    }


def _fake_openclaw_enabled():
    """Wrap the module's OpenClawService with an enabled instance so the
    mission runner actually runs the stage pipeline."""
    from app.services.openclaw_service import OpenClawService
    from app.api.v1.endpoints import openclaw as openclaw_ep

    svc = MagicMock(spec=OpenClawService)
    svc.enabled = True

    async def fake_generate(**kwargs):
        return {"success": True, "output": "stage complete"}

    svc.generate = AsyncMock(side_effect=fake_generate)
    svc.warmup = AsyncMock(return_value=True)

    fake_cls = MagicMock(return_value=svc)
    return patch.object(openclaw_ep, "OpenClawService", fake_cls)


def test_full_mission_flow_success_records_pr_url():
    """A mission with a repository + GitHub token + enough context should
    end with a PR opened and recorded in the pipeline snapshot."""
    from app.services.pipeline_status import pipeline_tracker
    from app.api.v1.endpoints import openclaw as openclaw_ep
    from app.services import mission_pr_service as mmod

    captured = {}

    async def fake_understand(self, repo_full_name, user_id=""):
        captured["understood"] = repo_full_name
        return _fake_understand_success(repo_full_name)

    async def fake_pr(self, **kwargs):
        captured["executed"] = kwargs
        return {
            "success": True,
            "pull_request_url": "https://github.com/HEETMEHTA18/tatvik/pull/101",
            "branch_name": "tatvik/mission-my-feature",
            "files_changed": ["backend/app/main.py"],
            "changes_count": 1,
            "repo": "HEETMEHTA18/tatvik",
        }

    pipeline_tracker.reset()
    pipeline_tracker.start_mission(
        title="Add health endpoint",
        description="Expose /health route",
        repository="https://github.com/HEETMEHTA18/tatvik",
    )
    with (
        _fake_openclaw_enabled(),
        patch.object(mmod.MissionPrService, "understand_repository", fake_understand),
        patch.object(mmod.MissionPrService, "execute_mission_and_open_pr", fake_pr),
    ):
        run_async(
            openclaw_ep._run_mission_in_background(
                title="Add health endpoint",
                description="Expose /health route",
                repository="https://github.com/HEETMEHTA18/tatvik",
                user_id="user-1",
                github_token="test-token",
            )
        )

    snapshot = pipeline_tracker.snapshot()
    mission = snapshot["mission"]
    assert (
        mission["pull_request_url"] == "https://github.com/HEETMEHTA18/tatvik/pull/101"
    )
    assert mission["branch_name"] == "tatvik/mission-my-feature"
    assert mission["repository"] == "https://github.com/HEETMEHTA18/tatvik"
    assert captured["understood"] == "HEETMEHTA18/tatvik"
    assert captured["executed"]["mission_title"] == "Add health endpoint"
    assert captured["executed"]["repo_full_name"] == "HEETMEHTA18/tatvik"
    assert any("Pull request opened" in e["message"] for e in snapshot["timeline"])


def test_mission_flow_without_repo_skips_pr():
    """Missions without a repository never attempt PR description or PR
    creation."""
    from app.services.pipeline_status import pipeline_tracker
    from app.api.v1.endpoints import openclaw as openclaw_ep
    from app.services import mission_pr_service as mmod

    called = {"understand": False, "pr": False}

    async def dont_understand(self, *a, **k):
        called["understand"] = True
        return {"success": False, "error": "should not run"}

    async def dont_pr(self, **k):
        called["pr"] = True
        return {"success": False, "error": "should not run"}

    pipeline_tracker.reset()
    with (
        _fake_openclaw_enabled(),
        patch.object(mmod.MissionPrService, "understand_repository", dont_understand),
        patch.object(mmod.MissionPrService, "execute_mission_and_open_pr", dont_pr),
    ):
        run_async(
            openclaw_ep._run_mission_in_background(
                title="Refactor docs",
                description="No repo targeted",
                repository="",
                user_id="user-1",
                github_token="test-token",
            )
        )

    assert called["understand"] is False
    assert called["pr"] is False


def test_mission_flow_without_token_is_graceful():
    """Without a GitHub token the mission still runs to completion but no PR
    is opened."""
    from app.services.pipeline_status import pipeline_tracker
    from app.api.v1.endpoints import openclaw as openclaw_ep

    pipeline_tracker.reset()
    with _fake_openclaw_enabled():
        run_async(
            openclaw_ep._run_mission_in_background(
                title="Docs only",
                description="No code changes needed",
                repository="https://github.com/HEETMEHT18/tatvik",
                user_id="user-1",
                github_token="",
            )
        )

    snapshot = pipeline_tracker.snapshot()
    assert snapshot["mission"]["pull_request_url"] == ""


def test_mission_flow_pr_failure_marks_mission_failed():
    """When GitHub rejects the PR, the mission must not finish as a success
    — all_ok drops to False and a PR failure event is recorded."""
    from app.services.pipeline_status import pipeline_tracker
    from app.api.v1.endpoints import openclaw as openclaw_ep
    from app.services import mission_pr_service as mmod

    async def fake_understand(self, repo_full_name, user_id=""):
        return _fake_understand_success(repo_full_name)

    async def pr_rejected(self, **kwargs):
        return {
            "success": False,
            "pr_error": "pull request already exists (422)",
            "error": "",
        }

    pipeline_tracker.reset()
    with (
        _fake_openclaw_enabled(),
        patch.object(mmod.MissionPrService, "understand_repository", fake_understand),
        patch.object(mmod.MissionPrService, "execute_mission_and_open_pr", pr_rejected),
    ):
        run_async(
            openclaw_ep._run_mission_in_background(
                title="Add health endpoint",
                description="x",
                repository="https://github.com/HEETMEHTA18/tatvik",
                user_id="user-1",
                github_token="test-token",
            )
        )

    snapshot = pipeline_tracker.snapshot()
    assert snapshot["mission"]["status"] in ("failed", "error")
    assert any("PR failed" in e["message"] for e in snapshot["timeline"])
