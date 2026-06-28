"""
Tests for Tatvik Architecture — Tool Registry, Planner, OpenClaw Engine, Webhooks.
All external API calls are mocked so tests run fully offline.
"""

import asyncio
import json
import pytest
from fastapi.testclient import TestClient
from unittest.mock import AsyncMock, patch, MagicMock

from app.main import app
from app.services.openclaw_tools import (
    get_all_tools_summary,
    get_architecture_stats,
    get_tool,
    list_tools_by_category,
    ToolCategory,
)
from app.services.tatvik_planner import TatvikPlanner
from app.services.openclaw_service import OpenClawService
from app.services.webhook_router import (
    parse_github_event,
    parse_slack_event,
    parse_jira_event,
    verify_github_signature,
    route_webhook_event,
    WebhookEvent,
    DEFAULT_AUTOMATION_RULES,
)

client = TestClient(app)


def setup_module():
    from app.db.base import Base
    from app.db.session import engine
    import app.api.v1.endpoints.research as research
    Base.metadata.create_all(bind=engine)
    research.redis_client = None


def get_auth_headers():
    client.post(
        "/api/v1/auth/register",
        json={"email": "openclaw_test@example.com", "password": "Password123!", "name": "OpenClaw Test"},
    )
    r = client.post(
        "/api/v1/auth/login",
        json={"email": "openclaw_test@example.com", "password": "Password123!"},
    )
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# ─── Tool Registry ────────────────────────────────────────────────────────────

def test_tool_registry_has_tools():
    tools = get_all_tools_summary()
    assert len(tools) >= 19, f"Expected ≥19 tools, got {len(tools)}"


def test_tool_registry_total_capabilities():
    stats = get_architecture_stats()
    caps = stats["architecture_layers"]["execution"]["total_capabilities"]
    assert caps >= 90, f"Expected ≥90 capabilities, got {caps}"


def test_tool_registry_github_capabilities():
    tool = get_tool("github")
    assert tool is not None
    cap_names = [c.name for c in tool.capabilities]
    for cap in ["create_pr", "merge_pr", "review_code", "create_release", "trigger_action"]:
        assert cap in cap_names, f"Missing GitHub capability: {cap}"


def test_tool_registry_all_tools_have_required_fields():
    tools = get_all_tools_summary()
    for t in tools:
        assert t["id"], "Tool missing id"
        assert t["name"], "Tool missing name"
        assert t["category"], "Tool missing category"
        assert t["capability_count"] > 0, f"{t['name']} has no capabilities"


def test_tool_registry_categories():
    stats = get_architecture_stats()
    cats = stats["architecture_layers"]["integrations"]["categories"]
    assert "devops" in cats
    assert "communication" in cats
    assert "cloud" in cats


def test_get_tool_by_id():
    for tool_id in ["github", "slack", "notion", "jira", "docker", "vercel", "figma"]:
        tool = get_tool(tool_id)
        assert tool is not None, f"Tool '{tool_id}' not found in registry"


def test_list_tools_by_category():
    devops = list_tools_by_category(ToolCategory.DEVOPS)
    assert len(devops) >= 2
    comm = list_tools_by_category(ToolCategory.COMMUNICATION)
    assert len(comm) >= 3


def test_architecture_stats_structure():
    stats = get_architecture_stats()
    assert stats["platform"] == "Tatvik AI Operating System"
    layers = stats["architecture_layers"]
    assert "intelligence" in layers
    assert "memory" in layers
    assert "execution" in layers
    assert "integrations" in layers
    assert len(stats["workflow_examples"]) >= 3
    assert len(stats["key_metrics"]) >= 6


# ─── Tatvik Planner ───────────────────────────────────────────────────────────

def _plan(goal, user="user-1"):
    return asyncio.get_event_loop().run_until_complete(
        TatvikPlanner().plan_workflow(goal, user)
    )


def test_planner_ship_release_template():
    wf = _plan("Ship version 3.2")
    assert len(wf.steps) > 0
    tool_ids = [s.tool_id for s in wf.steps]
    assert "github" in tool_ids
    assert "slack" in tool_ids


def test_planner_sprint_planning_template():
    wf = _plan("Sprint planning for this week")
    assert "jira" in [s.tool_id for s in wf.steps]


def test_planner_meeting_template():
    wf = _plan("Process meeting transcript")
    tool_ids = [s.tool_id for s in wf.steps]
    assert "notion" in tool_ids
    assert "cognee_memory" in tool_ids


def test_planner_pr_review_template():
    wf = _plan("Review PR #42")
    assert len(wf.steps) > 0


def test_planner_all_templates_produce_valid_steps():
    goals = [
        "Ship version 1.0", "Review PR #10", "Sprint planning",
        "Process meeting transcript", "Deploy feature branch", "Onboard new developer",
    ]
    for goal in goals:
        wf = _plan(goal)
        assert len(wf.steps) > 0, f"No steps for: {goal}"
        for step in wf.steps:
            assert step.tool_id and step.capability and step.step_number > 0


def test_planner_workflow_to_dict():
    planner = TatvikPlanner()
    wf = asyncio.get_event_loop().run_until_complete(planner.plan_workflow("Ship release", "u1"))
    d = planner.workflow_to_dict(wf)
    assert "goal" in d and "steps" in d and isinstance(d["steps"], list)


# ─── OpenClaw Service (forced dry-run / stub mode) ───────────────────────────
# We force enabled=False so tests run fully offline even when OPENCLAW_API_KEY is set.

def _run(coro):
    return asyncio.get_event_loop().run_until_complete(coro)


def _stub_svc():
    """Return an OpenClawService with enabled=False (stub mode)."""
    svc = OpenClawService()
    svc.enabled = False
    return svc


def test_openclaw_stub_execute_task():
    result = _run(_stub_svc().execute_task("https://github.com/test/repo", "Add tests"))
    assert result["success"] is True
    assert result.get("stub") is True


def test_openclaw_stub_tool_capability():
    result = _run(_stub_svc().execute_tool_capability("github", "create_pr", {"repo": "test/repo"}))
    assert result["success"] is True
    assert result.get("stub") is True


def test_openclaw_stub_github_create_release():
    result = _run(_stub_svc().github_create_release("test/repo", "v1.0.0", "First release"))
    assert result["success"] is True


def test_openclaw_stub_slack_post():
    result = _run(_stub_svc().slack_post_message("#general", "Hello from Tatvik!"))
    assert result["success"] is True


def test_openclaw_stub_notion_create_doc():
    result = _run(_stub_svc().notion_create_doc("Release Notes", "Version 1.0 released"))
    assert result["success"] is True


def test_openclaw_stub_run_terminal_command_valid():
    result = _run(_stub_svc().run_terminal_command("echo hello"))
    assert result["success"] is True


def test_openclaw_stub_run_terminal_command_invalid():
    # Invalid command check happens before enabled check
    svc = _stub_svc()
    result = _run(svc.run_terminal_command(""))
    assert result["success"] is False
    assert "error" in result


def test_openclaw_stub_docker_logs():
    result = _run(_stub_svc().docker_view_logs("my-container"))
    assert result["success"] is True


# ─── Webhook Parsers ──────────────────────────────────────────────────────────

def test_parse_github_pr_opened():
    payload = {
        "action": "opened",
        "number": 42,
        "pull_request": {
            "title": "Add new feature",
            "user": {"login": "heet18"},
            "base": {"ref": "main"},
            "head": {"ref": "feature-x"},
            "html_url": "https://github.com/test/repo/pull/42",
        },
        "repository": {"full_name": "test/repo"},
    }
    event = parse_github_event("pull_request", payload)
    assert event is not None
    assert event.source == "github"
    assert event.event_type == "pull_request.opened"
    assert event.payload["pr_number"] == 42
    assert event.payload["repo"] == "test/repo"


def test_parse_github_push():
    payload = {
        "ref": "refs/heads/main",
        "commits": [{"message": "fix: typo"}, {"message": "feat: new thing"}],
        "pusher": {"name": "heet18"},
        "repository": {"full_name": "test/repo"},
    }
    event = parse_github_event("push", payload)
    assert event is not None
    assert event.event_type == "push"
    assert event.payload["branch"] == "main"
    assert event.payload["commits"] == 2


def test_parse_github_issue_opened():
    payload = {
        "action": "opened",
        "issue": {
            "number": 7,
            "title": "Bug in auth",
            "body": "Auth breaks on mobile",
            "user": {"login": "heet18"},
            "labels": [{"name": "bug"}],
            "html_url": "https://github.com/test/repo/issues/7",
        },
        "repository": {"full_name": "test/repo"},
    }
    event = parse_github_event("issues", payload)
    assert event is not None
    assert event.event_type == "issue.opened"
    assert event.payload["issue_number"] == 7


def test_parse_github_release():
    payload = {
        "action": "published",
        "release": {
            "tag_name": "v2.0.0",
            "name": "Version 2.0",
            "body": "Major release",
            "html_url": "https://github.com/test/repo/releases/v2.0.0",
        },
        "repository": {"full_name": "test/repo"},
    }
    event = parse_github_event("release", payload)
    assert event is not None
    assert event.event_type == "release.published"
    assert event.payload["tag"] == "v2.0.0"


def test_parse_github_unknown_event_returns_none():
    event = parse_github_event("unknown_event_type", {})
    assert event is None


def test_parse_slack_message():
    payload = {
        "event": {
            "type": "message",
            "channel": "C12345",
            "user": "U12345",
            "text": "Hello Tatvik",
            "ts": "12345.67890",
        }
    }
    event = parse_slack_event(payload)
    assert event is not None
    assert event.source == "slack"
    assert event.event_type == "message"
    assert event.payload["text"] == "Hello Tatvik"


def test_parse_slack_app_mention():
    payload = {
        "event": {
            "type": "app_mention",
            "channel": "C99999",
            "user": "U99999",
            "text": "@tatvik ship version 3.2",
            "ts": "111.222",
        }
    }
    event = parse_slack_event(payload)
    assert event is not None
    assert event.event_type == "app_mention"


def test_parse_jira_issue_created():
    payload = {
        "webhookEvent": "jira:issue_created",
        "issue": {
            "key": "PROJ-42",
            "fields": {
                "summary": "Fix login bug",
                "status": {"name": "To Do"},
                "assignee": {"displayName": "Heet"},
                "priority": {"name": "High"},
                "project": {"key": "PROJ"},
            },
        },
    }
    event = parse_jira_event(payload)
    assert event is not None
    assert event.source == "jira"
    assert event.event_type == "issue.created"
    assert event.payload["issue_key"] == "PROJ-42"


def test_webhook_signature_skipped_when_no_secret(monkeypatch):
    monkeypatch.setattr("app.services.webhook_router.settings.github_webhook_secret", "")
    assert verify_github_signature(b"body", "sha256=anything") is True


def test_webhook_automation_rules_count():
    assert len(DEFAULT_AUTOMATION_RULES) >= 5


def test_webhook_rule_matching():
    event = WebhookEvent(
        source="github",
        event_type="pull_request.opened",
        payload={"pr_number": 1, "title": "Test PR", "repo": "test/repo"},
    )
    matched = [r for r in DEFAULT_AUTOMATION_RULES if r.matches(event)]
    assert len(matched) >= 1


def test_webhook_goal_rendering():
    event = WebhookEvent(
        source="github",
        event_type="pull_request.opened",
        payload={"pr_number": 5, "title": "My PR", "repo": "owner/repo"},
    )
    for rule in DEFAULT_AUTOMATION_RULES:
        if rule.matches(event):
            goal = rule.render_goal(event)
            assert "5" in goal or "My PR" in goal or "owner/repo" in goal
            break


# ─── API Endpoints ────────────────────────────────────────────────────────────

def test_api_architecture_endpoint():
    r = client.get("/api/v1/openclaw/architecture")
    assert r.status_code == 200
    data = r.json()
    assert data["success"] is True
    assert "architecture_layers" in data["data"]
    assert data["data"]["architecture_layers"]["execution"]["total_tools"] >= 19


def test_api_list_tools_endpoint():
    r = client.get("/api/v1/openclaw/tools")
    assert r.status_code == 200
    data = r.json()
    assert data["success"] is True
    assert data["total"] >= 19
    assert len(data["data"]) >= 19


def test_api_tool_detail_github():
    r = client.get("/api/v1/openclaw/tools/github")
    assert r.status_code == 200
    data = r.json()
    assert data["success"] is True
    assert data["data"]["id"] == "github"
    assert len(data["data"]["capabilities"]) >= 10


def test_api_tool_detail_not_found():
    r = client.get("/api/v1/openclaw/tools/nonexistent_tool_xyz")
    assert r.status_code == 404


def test_api_plan_endpoint_requires_auth():
    r = client.post("/api/v1/openclaw/plan", json={"goal": "Ship release"})
    assert r.status_code in (401, 403)


def test_api_plan_endpoint_with_auth():
    headers = get_auth_headers()
    r = client.post(
        "/api/v1/openclaw/plan",
        json={"goal": "Ship version 2.0", "execute": False},
        headers=headers,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["success"] is True
    assert "workflow" in data
    assert len(data["workflow"]["steps"]) > 0


def test_api_execute_endpoint_valid_tool():
    headers = get_auth_headers()
    r = client.post(
        "/api/v1/openclaw/execute",
        json={"tool_id": "slack", "capability": "post_message", "parameters": {"channel": "#test", "message": "hello"}},
        headers=headers,
    )
    assert r.status_code == 200
    assert r.json()["success"] is True


def test_api_execute_endpoint_invalid_tool():
    headers = get_auth_headers()
    r = client.post(
        "/api/v1/openclaw/execute",
        json={"tool_id": "unknown_tool", "capability": "do_stuff", "parameters": {}},
        headers=headers,
    )
    assert r.status_code == 404


def test_api_execute_endpoint_invalid_capability():
    headers = get_auth_headers()
    r = client.post(
        "/api/v1/openclaw/execute",
        json={"tool_id": "github", "capability": "nonexistent_cap", "parameters": {}},
        headers=headers,
    )
    assert r.status_code == 400


def test_api_webhook_github_no_signature():
    """No secret configured → should be accepted (dev mode)."""
    r = client.post(
        "/api/v1/openclaw/webhooks/github",
        json={
            "action": "opened",
            "number": 1,
            "pull_request": {
                "title": "Test PR",
                "user": {"login": "heet18"},
                "base": {"ref": "main"},
                "head": {"ref": "dev"},
                "html_url": "https://github.com/test/repo/pull/1",
            },
            "repository": {"full_name": "test/repo"},
        },
        headers={"X-GitHub-Event": "pull_request"},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["received"] is True


def test_api_webhook_slack_url_verification():
    r = client.post(
        "/api/v1/openclaw/webhooks/slack",
        json={"type": "url_verification", "challenge": "abc123xyz"},
    )
    assert r.status_code == 200
    assert r.json()["challenge"] == "abc123xyz"


def test_api_webhook_jira_issue():
    r = client.post(
        "/api/v1/openclaw/webhooks/jira",
        json={
            "webhookEvent": "jira:issue_created",
            "issue": {
                "key": "PROJ-1",
                "fields": {
                    "summary": "Bug found",
                    "status": {"name": "Open"},
                    "assignee": None,
                    "priority": {"name": "High"},
                    "project": {"key": "PROJ"},
                },
            },
        },
    )
    assert r.status_code == 200
    assert r.json()["received"] is True


def test_api_webhook_rules_endpoint():
    headers = get_auth_headers()
    r = client.get("/api/v1/openclaw/webhooks/rules", headers=headers)
    assert r.status_code == 200
    data = r.json()
    assert data["success"] is True
    assert data["total"] >= 5


def test_api_legacy_task_endpoint():
    headers = get_auth_headers()
    r = client.post(
        "/api/v1/openclaw/task",
        json={"repo_url": "https://github.com/test/repo", "task_description": "Add README"},
        headers=headers,
    )
    assert r.status_code == 200
    assert r.json()["success"] is True


def test_api_legacy_command_endpoint():
    headers = get_auth_headers()
    r = client.post(
        "/api/v1/openclaw/command",
        json={"command": "echo hello"},
        headers=headers,
    )
    assert r.status_code == 200
    assert r.json()["success"] is True
