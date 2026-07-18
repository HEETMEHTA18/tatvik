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
from datetime import datetime, timezone
from typing import Any

SAFE_RESULT_KEYS = {
    "success",
    "output",
    "message",
    "pull_request_url",
    "task_id",
    "status",
    "tool_id",
    "capability",
    "steps_executed",
}


def _sanitize_result(result: Any) -> dict:
    if not isinstance(result, dict):
        return {"success": False, "message": "Operation completed"}
    safe = {}
    for k, v in result.items():
        if k not in SAFE_RESULT_KEYS:
            continue
        if isinstance(v, Exception):
            continue
        if isinstance(v, str) and len(v) > 2000:
            safe[k] = v[:2000] + "..."
            continue
        safe[k] = v
    if "success" not in safe:
        safe["success"] = False
    return safe


def _sanitize_steps(steps: list[dict]) -> list[dict]:
    sanitized = []
    for step in steps:
        safe_step = {}
        for k, v in step.items():
            if k == "error":
                safe_step[k] = "step failed"
            elif k == "result":
                safe_step[k] = (
                    _sanitize_result(v)
                    if isinstance(v, dict)
                    else {"message": "completed"}
                )
            else:
                safe_step[k] = v
        sanitized.append(safe_step)
    return sanitized


from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    Header,
    HTTPException,
    Request,
    status,
)
from pydantic import BaseModel, Field

from app.api.deps import get_current_user_id, get_optional_user_id
from app.services.openclaw_service import OpenClawService
from app.services.openclaw_tools import (
    get_all_tools_summary,
    get_architecture_stats,
    get_tool,
)
from app.services.cognee_service import CogneeService
from app.services.tatvik_planner import TatvikPlanner
from app.services.pipeline_status import pipeline_tracker, PipelineStepInfo
from app.services.webhook_router import (
    DEFAULT_AUTOMATION_RULES,
    WebhookEvent,
    parse_github_event,
    parse_jira_event,
    parse_slack_event,
    route_webhook_event,
    verify_github_signature,
)

_cognee = CogneeService()

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
    execute: bool = Field(
        default=False, description="If true, execute the plan immediately"
    )


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


@router.get(
    "/architecture", summary="Tatvik architecture overview with accurate statistics"
)
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
        raise HTTPException(
            status_code=404, detail=f"Tool '{tool_id}' not found in registry"
        )
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


# ── Cognee Memory Helpers ──────────────────────────────────────────────────────


async def _recall_cognee_context(query: str) -> list[str]:
    """Pull relevant past context from Cognee knowledge graph."""
    if not _cognee.enabled:
        return []
    try:
        result = await _cognee.ask_codebase("system", query)
        if result and result != "Cognee is not configured. Cannot search codebase.":
            return [result]
    except Exception:
        pass
    return []


async def _store_mission_to_cognee(user_id: str):
    """Store the completed mission's summary into Cognee permanent memory."""
    snap = pipeline_tracker.snapshot()
    mission = snap.get("mission", {})
    if not mission.get("title"):
        return

    content_lines = [
        f"MISSION: {mission['title']}",
        f"DESCRIPTION: {mission.get('description', '')}",
        f"PRIORITY: {mission.get('priority', 'medium')}",
        f"REPOSITORY: {mission.get('repository', '')}",
        f"STATUS: {mission.get('status', 'completed')}",
        f"COMPLETED_AT: {datetime.now(timezone.utc).isoformat()}",
        "",
        "STAGES:",
    ]
    for s in snap.get("stages", []):
        content_lines.append(f"  - {s['name']}: {s['status']} ({s['progress']}%)")
        for st in s.get("steps", []):
            content_lines.append(f"    - {st['step']}: {st['status']}")

    content_lines.extend(["", "TIMELINE SUMMARY:"])
    for t in snap.get("timeline", [])[-10:]:
        content_lines.append(f"  - {t['message']}")

    await _cognee._store_text(
        f"mission_{mission['title'].replace(' ', '_')}",
        "\n".join(content_lines),
    )


# ── Missions ───────────────────────────────────────────────────────────────────


class CreateMissionRequest(BaseModel):
    title: str = Field(..., description="Mission title")
    description: str = Field(default="", description="Mission description")
    priority: str = Field(
        default="medium", description="low | medium | high | critical"
    )
    deadline: str = Field(default="", description="ISO deadline date")
    repository: str = Field(default="", description="Target GitHub repo")
    execute: bool = Field(default=False, description="Start executing immediately")


@router.post("/missions", summary="Create a new AI mission")
async def create_mission(
    body: CreateMissionRequest,
    background_tasks: BackgroundTasks,
    user_id: str = Depends(get_current_user_id),
):
    """
    Creates a new mission in the Tatvik pipeline.
    A mission flows through stages: Requirement → Planning → Design → Development → Testing → Review → Deployment → Memory.
    """
    pipeline_tracker.start_mission(
        title=body.title,
        description=body.description,
        priority=body.priority,
        deadline=body.deadline,
        repository=body.repository,
    )

    pipeline_tracker.register_agent(
        "planner", "Planner", "Goal decomposition & workflow planning"
    )
    pipeline_tracker.register_agent(
        "architect", "Architect", "System architecture & design"
    )
    pipeline_tracker.register_agent(
        "designer", "Designer", "UI/UX design & component generation"
    )
    pipeline_tracker.register_agent(
        "frontend", "Frontend", "React/Flutter code generation"
    )
    pipeline_tracker.register_agent("backend", "Backend", "API & database generation")
    pipeline_tracker.register_agent("qa", "QA", "Testing & quality assurance")
    pipeline_tracker.register_agent("devops", "DevOps", "Build & deployment")

    pipeline_tracker.add_event("Querying memory for past context...", "info")

    result = {"success": True, "mission": pipeline_tracker.snapshot()["mission"]}

    if body.execute:
        pipeline_tracker.set_phase("planning", "Starting mission execution...")
        pipeline_tracker.add_event(f"Mission '{body.title}' execution started", "info")
        pipeline_tracker.start_stage("requirement")
        pipeline_tracker.update_agent(
            "planner", "working", f"Analyzing requirements for: {body.title}", 10.0
        )
        result["execution_started"] = True

    return result


@router.get("/missions", summary="Get current mission status")
async def get_missions(user_id: str = Depends(get_current_user_id)):
    """Returns the current active mission with full pipeline status."""
    return pipeline_tracker.report()


@router.post(
    "/missions/complete", summary="Mark mission as complete and store to memory"
)
async def complete_mission(
    background_tasks: BackgroundTasks,
    user_id: str = Depends(get_current_user_id),
):
    """Completes the current mission and stores its summary to Cognee memory."""
    pipeline_tracker.finish(success=True)
    pipeline_tracker.complete_stage("memory", True)
    pipeline_tracker.update_agent("devops", "done", "Deployment complete", 100.0)
    pipeline_tracker.add_event("Mission complete. Storing to memory...", "info")

    # Store to Cognee in background
    background_tasks.add_task(_store_mission_to_cognee, user_id)

    return {"success": True, "message": "Mission completed and stored to memory."}


@router.post("/missions/cancel", summary="Cancel the current mission")
async def cancel_mission(user_id: str = Depends(get_current_user_id)):
    """Cancels the currently running mission."""
    pipeline_tracker.status.mission.status = "cancelled"
    pipeline_tracker.status.phase = "idle"
    pipeline_tracker.add_event("Mission cancelled by user", "info")
    return {"success": True, "message": "Mission cancelled."}


# ── Agents ─────────────────────────────────────────────────────────────────────


class AgentUpdateRequest(BaseModel):
    status: str = Field(default="", description="idle | working | done | failed")
    current_task: str = Field(default="", description="What the agent is doing")
    progress: float = Field(default=-1.0, ge=-1.0, le=100.0)
    confidence: float = Field(default=-1.0, ge=-1.0, le=100.0)
    log: str = Field(default="", description="Log message to append")


@router.get("/agents", summary="List all registered agents and their status")
async def list_agents(user_id: str = Depends(get_current_user_id)):
    """Returns the status of every registered AI agent in the pipeline."""
    snap = pipeline_tracker.snapshot()
    return {"success": True, "total": len(snap["agents"]), "agents": snap["agents"]}


@router.post(
    "/agents/{agent_id}/update",
    summary="Update an agent's status (called by agents themselves)",
)
async def update_agent_status(
    agent_id: str,
    body: AgentUpdateRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Allows an AI agent to report its status back to the pipeline tracker."""
    pipeline_tracker.update_agent(
        agent_id=agent_id,
        status=body.status or "",
        current_task=body.current_task or "",
        progress=body.progress,
        confidence=body.confidence,
        log=body.log or "",
    )
    return {"success": True}


# ── Timeline ──


@router.get("/timeline", summary="Get pipeline timeline events")
async def get_timeline(limit: int = 50, user_id: str = Depends(get_current_user_id)):
    """Returns the most recent timeline events from the pipeline."""
    snap = pipeline_tracker.snapshot()
    return {
        "success": True,
        "total": len(snap["timeline"]),
        "events": snap["timeline"][-limit:],
    }


# ── Pipeline Status ────────────────────────────────────────────────────────────


@router.get("/pipeline/status", summary="Current pipeline status and working info")
async def get_pipeline_status():
    """
    Returns real-time status of the Tatvik pipeline:
    - Configuration (enabled/disabled state)
    - Current phase, goal, and step-level execution progress
    - Stages, agents, timeline
    """
    return pipeline_tracker.report()


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
    pipeline_tracker.start_planning(body.goal)
    workflow = await planner.plan_workflow(
        goal=body.goal,
        user_id=user_id,
    )

    for i, s in enumerate(workflow.steps):
        pipeline_tracker.add_step(
            PipelineStepInfo(
                step=s.description or f"{s.tool_id}.{s.capability}",
                status="pending",
                tool_id=s.tool_id,
                capability=s.capability,
            )
        )

    result = {
        "success": True,
        "workflow": planner.workflow_to_dict(workflow),
    }

    if body.execute:
        pipeline_tracker.set_phase(
            "executing_openclaw", "Warming up OpenClaw engine..."
        )
        openclaw = OpenClawService()
        await openclaw.warmup()
        pipeline_tracker.set_phase(
            "executing_openclaw", "Executing workflow steps via OpenClaw..."
        )
        executed_steps = []
        for i, step in enumerate(workflow.steps):
            pipeline_tracker.update_step(
                i, "running", f"Running {step.tool_id}.{step.capability}..."
            )
            step_result = await openclaw.execute_tool_capability(
                tool_id=step.tool_id,
                capability=step.capability,
                parameters=step.parameters,
                user_context=body.goal,
            )
            ok = step_result.get("success", False)
            step.status = "done" if ok else "failed"
            step.result = step_result
            pipeline_tracker.update_step(i, step.status, step_result.get("output", ""))
            executed_steps.append(step_result)
        workflow.status = "completed"
        result["executed"] = True
        result["execution_results"] = executed_steps
        result["workflow"] = planner.workflow_to_dict(workflow)
        pipeline_tracker.finish(all(s.status == "done" for s in workflow.steps))

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
        raise HTTPException(
            status_code=404, detail=f"Tool '{body.tool_id}' not found in registry"
        )

    known_capabilities = [c.name for c in tool.capabilities]
    if body.capability not in known_capabilities:
        raise HTTPException(
            status_code=400,
            detail=f"Capability '{body.capability}' not found in tool '{body.tool_id}'. "
            f"Available: {known_capabilities}",
        )

    openclaw = OpenClawService()
    try:
        result = await openclaw.execute_tool_capability(
            tool_id=body.tool_id,
            capability=body.capability,
            parameters=body.parameters,
            user_context=body.user_context,
        )
        return {
            "success": result.get("success", False),
            "tool_id": body.tool_id,
            "capability": body.capability,
            "result": _sanitize_result(result),
        }
    except Exception:
        logger.exception("Tool execution failed")
        raise HTTPException(status_code=500, detail="Tool execution failed")


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

    try:
        workflow = await planner.plan_workflow(
            goal=f"Ship release {body.version} for {body.repo}",
            user_id=user_id,
        )
    except Exception:
        logger.exception("Workflow planning failed")
        raise HTTPException(status_code=500, detail="Workflow planning failed")

    steps_executed = []

    try:
        r1 = await openclaw.github_create_release(
            repo=body.repo, tag=body.version, notes=body.changelog
        )
        steps_executed.append({"step": "GitHub Release", "result": r1})
    except Exception as e:
        logger.warning("GitHub release step failed: %s", e)
        steps_executed.append({"step": "GitHub Release", "error": "step failed"})

    try:
        r2 = await openclaw.notion_create_doc(
            title=f"Release {body.version} — {body.repo}",
            content=body.changelog,
            parent_id=body.notion_parent_id,
        )
        steps_executed.append({"step": "Notion Docs", "result": r2})
    except Exception as e:
        logger.warning("Notion step failed: %s", e)
        steps_executed.append({"step": "Notion Docs", "error": "step failed"})

    try:
        if body.deploy_target == "vercel":
            r3 = await openclaw.vercel_deploy(repo=body.repo)
        else:
            r3 = await openclaw.execute_tool_capability(
                "railway", "deploy", {"project": body.repo, "service": "web"}
            )
        steps_executed.append(
            {"step": f"{body.deploy_target.title()} Deploy", "result": r3}
        )
    except Exception as e:
        logger.warning("Deploy step failed: %s", e)
        steps_executed.append({"step": "Deploy", "error": "step failed"})

    try:
        r4 = await openclaw.slack_post_release_notes(
            channel=body.slack_channel,
            version=body.version,
            notes=body.changelog,
        )
        steps_executed.append({"step": "Slack Notification", "result": r4})
    except Exception as e:
        logger.warning("Slack step failed: %s", e)
        steps_executed.append({"step": "Slack Notification", "error": "step failed"})

    return {
        "success": True,
        "workflow": planner.workflow_to_dict(workflow),
        "steps_executed": _sanitize_steps(steps_executed),
    }


@router.post(
    "/workflows/process-meeting", summary="Process a meeting transcript end-to-end"
)
async def process_meeting(
    body: MeetingTranscriptRequest,
    user_id: str = Depends(get_current_user_id),
):
    """
    Meeting → Notion notes → Linear issues → Slack summary → Cognee memory.
    """
    openclaw = OpenClawService()
    steps = []

    try:
        r1 = await openclaw.notion_create_meeting_notes(
            title=body.title, transcript=body.transcript
        )
        steps.append({"step": "Notion Meeting Notes", "result": r1})
    except Exception as e:
        logger.warning("Meeting notes step failed: %s", e)
        steps.append({"step": "Notion Meeting Notes", "error": "step failed"})

    if body.notify_slack_channel:
        try:
            r2 = await openclaw.slack_post_message(
                channel=body.notify_slack_channel,
                message=f"Meeting notes from *{body.title}* have been saved to Notion.",
            )
            steps.append({"step": "Slack Notification", "result": r2})
        except Exception as e:
            logger.warning("Slack step failed: %s", e)
            steps.append({"step": "Slack Notification", "error": "step failed"})

    return {"success": True, "steps_executed": _sanitize_steps(steps)}


# ── Legacy Endpoints (backward compatible) ────────────────────────────────────


@router.post("/task", summary="[Legacy] Execute a repository task via OpenClaw")
async def execute_legacy_task(
    body: ExecuteTaskRequest,
    user_id: str = Depends(get_current_user_id),
):
    openclaw = OpenClawService()
    try:
        result = await openclaw.execute_task(
            repo_url=body.repo_url,
            task_description=body.task_description,
            branch_name=body.branch_name,
        )
        return _sanitize_result(result)
    except Exception:
        logger.exception("Task execution failed")
        raise HTTPException(status_code=500, detail="Task execution failed")


@router.post("/command", summary="[Legacy] Run a terminal command inside OpenClaw")
async def run_terminal_command(
    body: RunCommandRequest,
    user_id: str = Depends(get_current_user_id),
):
    openclaw = OpenClawService()
    try:
        result = await openclaw.run_terminal_command(command=body.command)
        return _sanitize_result(result)
    except Exception:
        logger.exception("Command execution failed")
        raise HTTPException(status_code=500, detail="Command execution failed")


# ── Webhook Ingestion ─────────────────────────────────────────────────────────


@router.post(
    "/webhooks/github", summary="Ingest GitHub webhook events", include_in_schema=True
)
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
        return {
            "received": True,
            "processed": False,
            "reason": f"Unhandled event type: {x_github_event}",
        }

    async def process_in_background():
        result = await route_webhook_event(event, user_id="system")
        logger.info(
            f"[Webhook] GitHub {event.event_type} processed: {result.get('matched')}"
        )

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
        logger.info(
            f"[Webhook] Slack {event.event_type} processed: {result.get('matched')}"
        )

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
        logger.info(
            f"[Webhook] Jira {event.event_type} processed: {result.get('matched')}"
        )

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
