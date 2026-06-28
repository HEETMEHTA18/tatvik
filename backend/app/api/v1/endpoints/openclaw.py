"""
OpenClaw Execution Engine API
==============================
REST endpoints exposing the full Tatvik architecture:
  - Tool registry & architecture stats
  - Goal planning (Tatvik Planner)
  - Tool capability execution (OpenClaw)
  - Webhook event ingestion (Continuous automation)
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, BackgroundTasks, Depends, Header, HTTPException, Request, status
from pydantic import BaseModel, Field

from app.api.deps import get_current_user_id
from app.services.openclaw_service import OpenClawService
from app.services.openclaw_tools import get_all_tools_summary, get_architecture_stats, get_tool
from app.services.tatvik_planner import TatvikPlanner
from app.services.webhook_router import (
    DEFAULT_AUTOMATION_RULES,
    WebhookEvent,
    parse_github_event,
    parse_jira_event,
    parse_slack_event,
    route_webhook_event,
    verify_github_signature,
)

logger = logging.getLogger(__name__)
router = APIRouter()


# ── Request / Response Models ─────────────────────────────────────────────────

class ToolCapabilityRequest(BaseModel):
    tool_id: str = Field(..., description="Tool to invoke (e.g. 'github', 'slack')")
    capability: str = Field(..., description="Capability to execute (e.g. 'create_pr')")
    parameters: dict[str, Any] = Field(default_factory=dict)
    user_context: str = Field(default="", description="Optional context string")


class PlanGoalRequest(BaseModel):
    goal: str = Field(..., description="High-level goal in natural language")
    execute: bool = Field(default=False, description="If true, execute the plan immediately")


class ExecuteTaskRequest(BaseModel):
    """Legacy: direct task execution on a repository."""
    repo_url: str
    task_description: str
    branch_name: str | None = None


class RunCommandRequest(BaseModel):
    command: str


class MeetingTranscriptRequest(BaseModel):
    title: str
    transcript: str
    notify_slack_channel: str | None = None


class ShipReleaseRequest(BaseModel):
    repo: str
    version: str
    changelog: str
    slack_channel: str = "#releases"
    notion_parent_id: str = ""
    deploy_target: str = "vercel"  # vercel | railway | docker


# ── Architecture & Tool Registry ─────────────────────────────────────────────

@router.get("/architecture", summary="Tatvik architecture overview with accurate statistics")
async def get_architecture():
    """
    Returns the full Tatvik AI OS architecture overview:
    layers, statistics, tool count, capability count, and example workflows.
    """
    return {"success": True, "data": get_architecture_stats()}


@router.get("/tools", summary="List all registered OpenClaw tools")
async def list_tools():
    """Returns all tools in the OpenClaw universal tool registry."""
    tools = get_all_tools_summary()
    return {
        "success": True,
        "total": len(tools),
        "data": tools,
    }


@router.get("/tools/{tool_id}", summary="Get a specific tool's details")
async def get_tool_detail(tool_id: str):
    """Returns full detail for a specific tool including all capabilities."""
    tool = get_tool(tool_id)
    if not tool:
        raise HTTPException(status_code=404, detail=f"Tool '{tool_id}' not found in registry")
    return {
        "success": True,
        "data": {
            "id": tool.id,
            "name": tool.name,
            "category": tool.category.value,
            "description": tool.description,
            "icon": tool.icon,
            "requires_auth": tool.requires_auth,
            "is_implemented": tool.is_implemented,
            "stats": tool.stats,
            "capabilities": [
                {
                    "name": c.name,
                    "description": c.description,
                    "parameters": c.parameters,
                    "example": c.example,
                }
                for c in tool.capabilities
            ],
        },
    }


# ── Goal Planning ─────────────────────────────────────────────────────────────

@router.post("/plan", summary="Plan a workflow from a natural-language goal")
async def plan_goal(
    body: PlanGoalRequest,
    user_id: str = Depends(get_current_user_id),
):
    """
    The Tatvik Planner decomposes a high-level goal into an ordered list
    of OpenClaw tool capability calls. Optionally executes the plan.

    Example goals:
    - "Ship version 3.2"
    - "Review the latest PR on my repo"
    - "Prepare for tomorrow's sprint planning"
    - "Process the meeting transcript from today's standup"
    """
    planner = TatvikPlanner()
    workflow = await planner.plan_workflow(
        goal=body.goal,
        user_id=user_id,
    )
    result = {
        "success": True,
        "workflow": planner.workflow_to_dict(workflow),
    }

    if body.execute:
        # Execute each step sequentially via OpenClaw
        openclaw = OpenClawService()
        executed_steps = []
        for step in workflow.steps:
            step_result = await openclaw.execute_tool_capability(
                tool_id=step.tool_id,
                capability=step.capability,
                parameters=step.parameters,
                user_context=body.goal,
            )
            step.status = "done" if step_result.get("success") else "failed"
            step.result = step_result
            executed_steps.append(step_result)
        workflow.status = "completed"
        result["executed"] = True
        result["execution_results"] = executed_steps
        result["workflow"] = planner.workflow_to_dict(workflow)

    return result


# ── Tool Capability Execution ─────────────────────────────────────────────────

@router.post("/execute", summary="Execute a specific tool capability")
async def execute_tool_capability(
    body: ToolCapabilityRequest,
    user_id: str = Depends(get_current_user_id),
):
    """
    Execute a specific OpenClaw tool capability directly.
    This is the core execution endpoint of the Tatvik architecture.

    Examples:
    - {"tool_id": "github", "capability": "create_pr", "parameters": {...}}
    - {"tool_id": "slack", "capability": "post_message", "parameters": {...}}
    - {"tool_id": "docker", "capability": "view_logs", "parameters": {...}}
    """
    tool = get_tool(body.tool_id)
    if not tool:
        raise HTTPException(status_code=404, detail=f"Tool '{body.tool_id}' not found in registry")

    known_capabilities = [c.name for c in tool.capabilities]
    if body.capability not in known_capabilities:
        raise HTTPException(
            status_code=400,
            detail=f"Capability '{body.capability}' not found in tool '{body.tool_id}'. "
                   f"Available: {known_capabilities}",
        )

    openclaw = OpenClawService()
    result = await openclaw.execute_tool_capability(
        tool_id=body.tool_id,
        capability=body.capability,
        parameters=body.parameters,
        user_context=body.user_context,
    )
    return {"success": result.get("success", False), "tool_id": body.tool_id, "capability": body.capability, "result": result}


# ── High-Level Workflow Shortcuts ─────────────────────────────────────────────

@router.post("/workflows/ship-release", summary="Ship a full release (plan → execute)")
async def ship_release(
    body: ShipReleaseRequest,
    user_id: str = Depends(get_current_user_id),
):
    """
    End-to-end release workflow:
    Read GitHub → Check Jira → Run tests → Create release → Update Notion → Deploy → Notify Slack.
    """
    openclaw = OpenClawService()
    planner = TatvikPlanner()

    workflow = await planner.plan_workflow(
        goal=f"Ship release {body.version} for {body.repo}",
        user_id=user_id,
    )

    steps_executed = []

    # 1. Create GitHub release
    r1 = await openclaw.github_create_release(
        repo=body.repo, tag=body.version, notes=body.changelog
    )
    steps_executed.append({"step": "GitHub Release", "result": r1})

    # 2. Update Notion
    r2 = await openclaw.notion_create_doc(
        title=f"Release {body.version} — {body.repo}",
        content=body.changelog,
        parent_id=body.notion_parent_id,
    )
    steps_executed.append({"step": "Notion Docs", "result": r2})

    # 3. Deploy
    if body.deploy_target == "vercel":
        r3 = await openclaw.vercel_deploy(repo=body.repo)
    else:
        r3 = await openclaw.execute_tool_capability(
            "railway", "deploy", {"project": body.repo, "service": "web"}
        )
    steps_executed.append({"step": f"{body.deploy_target.title()} Deploy", "result": r3})

    # 4. Notify Slack
    r4 = await openclaw.slack_post_release_notes(
        channel=body.slack_channel,
        version=body.version,
        notes=body.changelog,
    )
    steps_executed.append({"step": "Slack Notification", "result": r4})

    return {
        "success": True,
        "workflow": planner.workflow_to_dict(workflow),
        "steps_executed": steps_executed,
    }


@router.post("/workflows/process-meeting", summary="Process a meeting transcript end-to-end")
async def process_meeting(
    body: MeetingTranscriptRequest,
    user_id: str = Depends(get_current_user_id),
):
    """
    Meeting → Notion notes → Linear issues → Slack summary → Cognee memory.
    """
    openclaw = OpenClawService()
    steps = []

    r1 = await openclaw.notion_create_meeting_notes(title=body.title, transcript=body.transcript)
    steps.append({"step": "Notion Meeting Notes", "result": r1})

    if body.notify_slack_channel:
        r2 = await openclaw.slack_post_message(
            channel=body.notify_slack_channel,
            message=f"📋 Meeting notes from *{body.title}* have been saved to Notion.",
        )
        steps.append({"step": "Slack Notification", "result": r2})

    return {"success": True, "steps_executed": steps}


# ── Legacy Endpoints (backward compatible) ────────────────────────────────────

@router.post("/task", summary="[Legacy] Execute a repository task via OpenClaw")
async def execute_legacy_task(
    body: ExecuteTaskRequest,
    user_id: str = Depends(get_current_user_id),
):
    openclaw = OpenClawService()
    result = await openclaw.execute_task(
        repo_url=body.repo_url,
        task_description=body.task_description,
        branch_name=body.branch_name,
    )
    return result


@router.post("/command", summary="[Legacy] Run a terminal command inside OpenClaw")
async def run_terminal_command(
    body: RunCommandRequest,
    user_id: str = Depends(get_current_user_id),
):
    openclaw = OpenClawService()
    result = await openclaw.run_terminal_command(command=body.command)
    return result


# ── Webhook Ingestion ─────────────────────────────────────────────────────────

@router.post("/webhooks/github", summary="Ingest GitHub webhook events", include_in_schema=True)
async def github_webhook(
    request: Request,
    background_tasks: BackgroundTasks,
    x_github_event: str | None = Header(default=None),
    x_hub_signature_256: str | None = Header(default=None),
):
    """
    Receives GitHub webhook events and automatically triggers Tatvik workflows.

    Supported events:
    - pull_request (opened, closed/merged, reviewed)
    - push
    - issues (opened, assigned)
    - release (published)
    - workflow_run (completed)
    """
    raw_body = await request.body()

    if not verify_github_signature(raw_body, x_hub_signature_256):
        raise HTTPException(status_code=401, detail="Invalid GitHub webhook signature")

    payload = await request.json()
    event = parse_github_event(event_header=x_github_event or "", payload=payload)

    if not event:
        return {"received": True, "processed": False, "reason": f"Unhandled event type: {x_github_event}"}

    async def process_in_background():
        result = await route_webhook_event(event, user_id="system")
        logger.info(f"[Webhook] GitHub {event.event_type} processed: {result.get('matched')}")

    background_tasks.add_task(process_in_background)
    return {
        "received": True,
        "processed": True,
        "event_source": "github",
        "event_type": event.event_type,
        "scheduled": True,
    }


@router.post("/webhooks/slack", summary="Ingest Slack Events API payloads")
async def slack_webhook(request: Request, background_tasks: BackgroundTasks):
    """Receives Slack Events API payloads and routes them to Tatvik workflows."""
    payload = await request.json()

    # Handle Slack URL verification challenge
    if payload.get("type") == "url_verification":
        return {"challenge": payload.get("challenge")}

    event = parse_slack_event(payload)
    if not event:
        return {"received": True, "processed": False}

    async def process_in_background():
        result = await route_webhook_event(event, user_id="system")
        logger.info(f"[Webhook] Slack {event.event_type} processed: {result.get('matched')}")

    background_tasks.add_task(process_in_background)
    return {"received": True, "processed": True, "event_type": event.event_type}


@router.post("/webhooks/jira", summary="Ingest Jira webhook events")
async def jira_webhook(request: Request, background_tasks: BackgroundTasks):
    """Receives Jira webhook events and routes them to Tatvik workflows."""
    payload = await request.json()
    event = parse_jira_event(payload)
    if not event:
        return {"received": True, "processed": False}

    async def process_in_background():
        result = await route_webhook_event(event, user_id="system")
        logger.info(f"[Webhook] Jira {event.event_type} processed: {result.get('matched')}")

    background_tasks.add_task(process_in_background)
    return {"received": True, "processed": True, "event_type": event.event_type}


@router.get("/webhooks/rules", summary="List active automation rules")
async def list_automation_rules(user_id: str = Depends(get_current_user_id)):
    """Returns all active webhook automation rules."""
    return {
        "success": True,
        "total": len(DEFAULT_AUTOMATION_RULES),
        "rules": [
            {
                "source": r.source,
                "event_type_prefix": r.event_type_prefix,
                "goal_template": r.goal_template,
                "enabled": r.enabled,
            }
            for r in DEFAULT_AUTOMATION_RULES
        ],
    }
