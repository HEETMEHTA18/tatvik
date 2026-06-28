"""
Webhook Event Router — Continuous Automation Engine
=====================================================
Tatvik should never stop working. This module handles inbound webhook
events from GitHub, Slack, Discord, and other sources, then dispatches
them into automated Tatvik Workflows via the Planner → OpenClaw pipeline.

Event Sources:
  GitHub Webhook → PR events, push events, issue events, release events
  Slack Events   → Message events, mention events
  Discord        → Message events
  Calendar       → Event reminders
  Jira           → Issue created/updated events
"""

from __future__ import annotations

import hashlib
import hmac
import logging
from datetime import datetime
from typing import Any

from app.core.config import settings

logger = logging.getLogger(__name__)


# ── Event Definitions ────────────────────────────────────────────────────────

class WebhookEvent:
    """Represents a normalized inbound webhook event."""
    def __init__(
        self,
        source: str,
        event_type: str,
        payload: dict[str, Any],
        received_at: str | None = None,
    ):
        self.source = source          # "github", "slack", "jira", etc.
        self.event_type = event_type  # "pull_request.opened", "issue.created", etc.
        self.payload = payload
        self.received_at = received_at or datetime.utcnow().isoformat()


# ── Webhook Verification ─────────────────────────────────────────────────────

def verify_github_signature(payload_bytes: bytes, signature_header: str | None) -> bool:
    """
    Verify GitHub webhook HMAC-SHA256 signature.
    Returns True if valid, False if the webhook secret is not set (dev mode).
    """
    secret = settings.github_webhook_secret
    if not secret:
        logger.warning("GitHub webhook secret not set — skipping signature verification.")
        return True

    if not signature_header or not signature_header.startswith("sha256="):
        return False

    expected = "sha256=" + hmac.new(
        secret.encode(), payload_bytes, hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature_header)


# ── Event Parsers ─────────────────────────────────────────────────────────────

def parse_github_event(event_header: str, payload: dict) -> WebhookEvent | None:
    """
    Normalize a GitHub webhook event into a WebhookEvent.
    Handles: pull_request, push, issues, create, release, workflow_run.
    """
    action = payload.get("action", "")

    if event_header == "pull_request":
        return WebhookEvent(
            source="github",
            event_type=f"pull_request.{action}",
            payload={
                "pr_number": payload.get("number"),
                "title": payload.get("pull_request", {}).get("title"),
                "repo": payload.get("repository", {}).get("full_name"),
                "author": payload.get("pull_request", {}).get("user", {}).get("login"),
                "base": payload.get("pull_request", {}).get("base", {}).get("ref"),
                "head": payload.get("pull_request", {}).get("head", {}).get("ref"),
                "url": payload.get("pull_request", {}).get("html_url"),
            },
        )

    if event_header == "push":
        return WebhookEvent(
            source="github",
            event_type="push",
            payload={
                "repo": payload.get("repository", {}).get("full_name"),
                "branch": payload.get("ref", "").replace("refs/heads/", ""),
                "commits": len(payload.get("commits", [])),
                "pusher": payload.get("pusher", {}).get("name"),
                "commit_messages": [c.get("message") for c in payload.get("commits", [])[:5]],
            },
        )

    if event_header == "issues":
        return WebhookEvent(
            source="github",
            event_type=f"issue.{action}",
            payload={
                "issue_number": payload.get("issue", {}).get("number"),
                "title": payload.get("issue", {}).get("title"),
                "body": payload.get("issue", {}).get("body", ""),
                "repo": payload.get("repository", {}).get("full_name"),
                "author": payload.get("issue", {}).get("user", {}).get("login"),
                "labels": [l.get("name") for l in payload.get("issue", {}).get("labels", [])],
                "url": payload.get("issue", {}).get("html_url"),
            },
        )

    if event_header == "release":
        return WebhookEvent(
            source="github",
            event_type=f"release.{action}",
            payload={
                "tag": payload.get("release", {}).get("tag_name"),
                "name": payload.get("release", {}).get("name"),
                "body": payload.get("release", {}).get("body", ""),
                "repo": payload.get("repository", {}).get("full_name"),
                "url": payload.get("release", {}).get("html_url"),
            },
        )

    if event_header == "workflow_run":
        conclusion = payload.get("workflow_run", {}).get("conclusion")
        return WebhookEvent(
            source="github",
            event_type=f"workflow_run.{action}",
            payload={
                "workflow_name": payload.get("workflow_run", {}).get("name"),
                "repo": payload.get("repository", {}).get("full_name"),
                "conclusion": conclusion,
                "branch": payload.get("workflow_run", {}).get("head_branch"),
                "url": payload.get("workflow_run", {}).get("html_url"),
            },
        )

    return None


def parse_slack_event(payload: dict) -> WebhookEvent | None:
    """
    Normalize a Slack Events API payload into a WebhookEvent.
    """
    event = payload.get("event", {})
    event_type = event.get("type", "")

    if event_type in ("message", "app_mention"):
        return WebhookEvent(
            source="slack",
            event_type=event_type,
            payload={
                "channel": event.get("channel"),
                "user": event.get("user"),
                "text": event.get("text", ""),
                "ts": event.get("ts"),
                "thread_ts": event.get("thread_ts"),
            },
        )
    return None


def parse_jira_event(payload: dict) -> WebhookEvent | None:
    """
    Normalize a Jira webhook payload into a WebhookEvent.
    """
    webhook_event = payload.get("webhookEvent", "")
    issue = payload.get("issue", {})
    fields = issue.get("fields", {})

    event_type_map = {
        "jira:issue_created": "issue.created",
        "jira:issue_updated": "issue.updated",
        "jira:issue_deleted": "issue.deleted",
    }

    return WebhookEvent(
        source="jira",
        event_type=event_type_map.get(webhook_event, webhook_event),
        payload={
            "issue_key": issue.get("key"),
            "summary": fields.get("summary", ""),
            "status": fields.get("status", {}).get("name"),
            "assignee": (fields.get("assignee") or {}).get("displayName"),
            "priority": fields.get("priority", {}).get("name"),
            "project": fields.get("project", {}).get("key"),
        },
    )


# ── Automation Rules ─────────────────────────────────────────────────────────

class AutomationRule:
    """Maps a WebhookEvent type to an automated goal passed to the Tatvik Planner."""
    def __init__(self, source: str, event_type_prefix: str, goal_template: str, enabled: bool = True):
        self.source = source
        self.event_type_prefix = event_type_prefix
        self.goal_template = goal_template
        self.enabled = enabled

    def matches(self, event: WebhookEvent) -> bool:
        return (
            self.enabled
            and event.source == self.source
            and event.event_type.startswith(self.event_type_prefix)
        )

    def render_goal(self, event: WebhookEvent) -> str:
        """Render the goal string by interpolating event payload fields."""
        try:
            return self.goal_template.format(**event.payload)
        except KeyError:
            return self.goal_template


# Default automation rules — Tatvik never stops working
DEFAULT_AUTOMATION_RULES: list[AutomationRule] = [
    AutomationRule(
        source="github",
        event_type_prefix="pull_request.opened",
        goal_template="Review PR #{pr_number} '{title}' on {repo} and post review comments",
    ),
    AutomationRule(
        source="github",
        event_type_prefix="pull_request.merged",
        goal_template="Update Notion changelog and notify Slack that PR #{pr_number} '{title}' was merged to {repo}",
    ),
    AutomationRule(
        source="github",
        event_type_prefix="issue.opened",
        goal_template="Triage new issue #{issue_number} '{title}' on {repo}: find similar bugs, recommend assignee, estimate difficulty",
    ),
    AutomationRule(
        source="github",
        event_type_prefix="release.published",
        goal_template="Post release notes for {tag} '{name}' on {repo} to Slack and update Notion roadmap",
    ),
    AutomationRule(
        source="github",
        event_type_prefix="workflow_run",
        goal_template="CI/CD pipeline '{workflow_name}' completed on {repo} with status {conclusion} — notify team if failed",
    ),
    AutomationRule(
        source="jira",
        event_type_prefix="issue.created",
        goal_template="New Jira issue {issue_key} '{summary}' in {project} — search docs, find related PRs, recommend assignee",
    ),
    AutomationRule(
        source="slack",
        event_type_prefix="app_mention",
        goal_template="Respond to Slack mention in channel {channel}: '{text}'",
    ),
]


async def route_webhook_event(
    event: WebhookEvent,
    user_id: str = "system",
    rules: list[AutomationRule] | None = None,
) -> dict:
    """
    Routes an inbound webhook event to an automated Tatvik workflow.
    Returns the planned workflow or an empty dict if no rule matched.
    """
    active_rules = rules or DEFAULT_AUTOMATION_RULES

    for rule in active_rules:
        if rule.matches(event):
            goal = rule.render_goal(event)
            logger.info(
                f"[WebhookRouter] Matched rule for {event.source}.{event.event_type}: '{goal}'"
            )

            # Import here to avoid circular imports
            from app.services.tatvik_planner import TatvikPlanner
            from app.services.cognee_service import CogneeService

            # Fetch memory context
            memory_context: list[str] = []
            try:
                cognee = CogneeService()
                context_result = await cognee.get_developer_profile(user_id)
                if isinstance(context_result, dict) and context_result.get("results"):
                    memory_context = [str(context_result["results"])]
            except Exception as e:
                logger.warning(f"[WebhookRouter] Could not fetch memory context: {e}")

            planner = TatvikPlanner()
            workflow = await planner.plan_workflow(
                goal=goal,
                user_id=user_id,
                memory_context=memory_context,
            )
            return {
                "matched": True,
                "rule": rule.event_type_prefix,
                "goal": goal,
                "workflow": planner.workflow_to_dict(workflow),
                "event_source": event.source,
                "event_type": event.event_type,
                "received_at": event.received_at,
            }

    logger.debug(f"[WebhookRouter] No rule matched for {event.source}.{event.event_type}")
    return {"matched": False, "event_source": event.source, "event_type": event.event_type}
