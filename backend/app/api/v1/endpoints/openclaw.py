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

import json
import logging
import hashlib
import re
import time
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


# In-process cache for mission stage outputs so identical missions/retries do
# not re-dispatch to the HF gateway (biggest free-tier quota saver).
_STAGE_CACHE: dict[str, tuple[float, str]] = {}


def _split_batch_output(text: str, stage_ids: list[str]) -> dict[str, str] | None:
    """Parse a batched stage reply into {stage_id: content}.

    The gateway returns either a strict JSON object ({"requirement": "...", ...})
    or a markdown-fenced JSON blob. Returns None when the reply cannot be parsed
    so the caller can fall back to per-stage dispatch.
    """
    if not text:
        return None
    cleaned = re.sub(r"```(?:json)?", "", text).strip()
    try:
        start = cleaned.find("{")
        end = cleaned.rfind("}")
        if start < 0 or end <= start:
            raise ValueError("no JSON object found")
        data = json.loads(cleaned[start : end + 1])
    except Exception:
        return None
    if not isinstance(data, dict):
        return None

    outputs = {}
    for sid in stage_ids:
        content = data.get(sid)
        if isinstance(content, str) and content.strip():
            outputs[sid] = content.strip()
    return outputs or None


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

from sqlalchemy.orm import Session
from app.core.config import settings
from app.api.deps import get_current_user_id, get_optional_user_id, get_db
from app.models.entities import PromptHistory, ExecutedCommand, GithubProfile
from app.services.openclaw_service import OpenClawService
from app.services.openclaw_tools import (
    get_all_tools_summary,
    get_architecture_stats,
    get_tool,
)
from app.services.cognee_service import CogneeService
from app.services.mission_pr_service import MissionPrService
from app.services.tatvik_planner import TatvikPlanner
from app.services.pipeline_status import (
    pipeline_tracker,
    PipelineStepInfo,
    STAGE_FLOW,
)
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


@router.get("/skills", summary="List developer skills (AutoDevs + skills.sh)")
async def list_developer_skills(user_id: str = Depends(get_current_user_id)):
    """Returns the frontend/backend developer skill registry the mission agent
    applies when planning PR changes (AutoDevs.dev profiles + skills.sh)."""
    from app.services.developer_skills import skills_registry

    return {"success": True, "data": skills_registry()}


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


async def _run_mission_in_background(
    title: str,
    description: str,
    repository: str,
    user_id: str = "",
    github_token: str = "",
):
    """
    Executes a mission end-to-end through the OpenClaw (HF Space) gateway.
    Each pipeline stage is dispatched as a real gateway request, so the
    activity shows up in the HF Space logs and the pipeline tracker progresses
    in real time instead of hanging at 'planning'.

    When a target repository is supplied the mission first understands the
    repository via the knowledge graph and — if significant changes are found —
    ends by opening a proper pull request with those changes.
    """
    openclaw = OpenClawService()
    mission = MissionPrService(github_token)

    if not openclaw.enabled:
        pipeline_tracker.set_phase(
            "idle", "OpenClaw is not configured. Mission paused."
        )
        pipeline_tracker.add_event(
            "OpenClaw gateway not configured — mission cannot execute.", "error"
        )
        return

    # ── Stage 0: understand the repository via the graph ─────────────────────
    repo_context = ""
    target_repo = ""
    if repository:
        target_repo = repository.replace("https://github.com/", "").strip("/")
        pipeline_tracker.set_phase(
            "requirement",
            f"Understanding repository context: {target_repo}",
        )
        pipeline_tracker.add_event(
            f"Querying the knowledge graph for repository '{target_repo}'...",
            "info",
        )
        understood = await mission.understand_repository(target_repo, user_id=user_id)
        if understood.get("success"):
            repo_context = understood["context"].get("rendered", "")
            pipeline_tracker.set_repo_context(repo_context)
            if understood["context"].get("graph_context"):
                pipeline_tracker.add_event(
                    "Matched repository memory from the knowledge graph.", "info"
                )
            pipeline_tracker.add_event(
                f"Understood {target_repo}: "
                f"{len(understood['context'].get('file_tree', []))} files mapped.",
                "info",
            )
        else:
            pipeline_tracker.add_event(
                f"Could not understand repository: {understood.get('error')}",
                "error",
            )

    mission_line = f"'{title}'" + (f" on {repository}" if repository else "")
    context_block = ""
    if repo_context:
        context_block = (
            "\n\nREPOSITORY CONTEXT (from the knowledge graph):\n" + repo_context[:4000]
        )
    # Give every stage the developer skills guidance so responses respect the
    # repo's frontend/backend stack and conventions (AutoDevs + skills.sh).
    skills_block = ""
    try:
        from app.services.developer_skills import build_skills_context

        skills_block = build_skills_context([], [])
    except Exception:
        pass
    if skills_block:
        context_block += "\n\n" + skills_block
    stage_prompts = {
        "requirement": (
            f"Analyze the requirements for mission {mission_line}. "
            f"Mission description: {description or 'Not provided'}. "
            "Return a concise, structured list of functional requirements."
            + context_block
        ),
        "planning": (
            f"Create an architecture plan for mission {mission_line}. "
            "Outline the tech stack, modules, data flow, and key design decisions. "
            "Return a concise structured plan."
        ),
        "design": (
            f"Design the UI/UX and system interfaces for mission {mission_line}. "
            "Describe screens, components, APIs, and data contracts. "
            "Return a concise structured design spec."
        ),
        "development": (
            f"Implement mission {mission_line}. "
            "Describe the code modules, file structure, and implementation steps "
            "needed to complete the mission. Return a concise structured plan."
        ),
        "testing": (
            f"Define a testing strategy for mission {mission_line}. "
            "List test cases, QA checks, and success criteria. "
            "Return a concise structured list."
        ),
        "review": (
            f"Perform a code review checklist for mission {mission_line}. "
            "List quality gates, security checks, and review criteria. "
            "Return a concise structured checklist."
        ),
        "deployment": (
            f"Plan the deployment for mission {mission_line}. "
            "Describe CI/CD steps, environments, and rollout strategy. "
            "Return a concise structured plan."
        ),
        "memory": (
            f"Summarize the completed mission {mission_line} for permanent memory. "
            "Return a concise structured summary with key outcomes and artifacts."
        ),
    }

    stage_agents = {
        "requirement": ("planner", "Analyzing requirements", 10.0),
        "planning": ("architect", "Designing architecture", 25.0),
        "design": ("designer", "Creating UI/UX design", 40.0),
        "development": ("backend", "Building implementation", 55.0),
        "testing": ("qa", "Running tests & QA", 70.0),
        "review": ("reviewer", "Reviewing code", 80.0),
        "deployment": ("devops", "Deploying", 90.0),
        "memory": ("devops", "Storing to memory", 100.0),
    }

    system_ctx = (
        "You are the Tatvik AI OS pipeline agent. You execute each stage of a "
        "development mission precisely and return concise, structured results "
        "that a project tracker can display."
    )

    # ── Per-stage output cache (re-run/retry protection) ─────────────────────

    def _cache_key(stage_id: str) -> str:
        return hashlib.sha256(
            f"{title}|||{description}|||{repository}|||{stage_id}".encode("utf-8")
        ).hexdigest()

    def _cache_get(stage_id: str) -> str | None:
        if not getattr(settings, "pipeline_stage_cache_enabled", True):
            return None
        entry = _STAGE_CACHE.get(_cache_key(stage_id))
        if not entry:
            return None
        ttl = int(getattr(settings, "pipeline_stage_cache_ttl", 3600))
        if time.monotonic() - entry[0] > ttl:
            _STAGE_CACHE.pop(_cache_key(stage_id), None)
            return None
        return entry[1]

    def _cache_put(stage_id: str, output: str):
        if not getattr(settings, "pipeline_stage_cache_enabled", True):
            return
        if len(_STAGE_CACHE) > 64:
            _STAGE_CACHE.clear()
        _STAGE_CACHE[_cache_key(stage_id)] = (time.monotonic(), output)

    async def _dispatch_stage(stage_id: str, prompt: str) -> dict:
        """Single stage dispatch through the gateway (with cache + bootstrap
        guard handled inside OpenClawService)."""
        try:
            return await openclaw.generate(
                prompt, system_context=system_ctx, timeout=240.0
            )
        except Exception as e:
            logger.warning(f"Stage '{stage_id}' dispatch error: {e}")
            return {"success": False, "error": str(e)}

    all_ok = True

    def _record_stage_result(stage_id: str, output: str, ok: bool):
        """Shared bookkeeping for a finished stage — keeps tracker + cache in sync."""
        stage_name = next(
            (name for sid, name in STAGE_FLOW if sid == stage_id), stage_id
        )
        agent_id, task, progress = stage_agents.get(
            stage_id, ("devops", "Working", 0.0)
        )
        _cache_put(stage_id, output)
        pipeline_tracker.complete_stage(stage_id, ok)
        pipeline_tracker.update_stage(
            stage_id, 100.0 if ok else 50.0, output[:2000] or "Completed"
        )
        pipeline_tracker.update_agent(
            agent_id,
            "done" if ok else "failed",
            f"{task} {'complete' if ok else 'failed'}",
            progress,
            90.0 if ok else 10.0,
        )
        pipeline_tracker.add_event(
            f"Stage '{stage_name}' {'completed.' if ok else 'failed.'}",
            "stage_completed" if ok else "error",
            stage_id,
        )

    async def _run_batch(stage_ids: list[str]) -> dict[str, str]:
        """Dispatch a group of stages in ONE gateway call, split the JSON reply
        locally, and fall back to per-stage dispatch if the reply is not JSON."""
        outputs: dict[str, str] = {}
        for sid in stage_ids:
            cached = _cache_get(sid)
            if cached is not None:
                outputs[sid] = cached

        pending = [s for s in stage_ids if s not in outputs]
        if not pending:
            return outputs

        lines = []
        for sid in pending:
            label = next((name for i, name in STAGE_FLOW if i == sid), sid)
            lines.append(f"- {sid} ({label}): {stage_prompts[sid]}")
        batch_prompt = (
            f"Execute these mission stages for {mission_line} in one pass.\n"
            f"Mission description: {description or 'Not provided'}.\n"
            + (context_block if context_block else "")
            + "\n\nStages:\n"
            + "\n".join(lines)
            + "\n\n"
            "Return STRICT JSON — one key per stage, e.g. "
            f'{{"{pending[0]}": "stage output", ...}}. No markdown fences, no commentary.'
        )
        result = await _dispatch_stage("+".join(pending), batch_prompt)
        if result.get("success"):
            text = str(result.get("output", ""))
            split = _split_batch_output(text, pending)
            if split:
                for sid, content in split.items():
                    outputs[sid] = content
                    _cache_put(sid, content)
                return outputs

        # Fall back to per-stage dispatch for the pending stages.
        for sid in pending:
            result = await _dispatch_stage(sid, stage_prompts[sid])
            if result.get("success"):
                content = str(result.get("output", ""))[:2000]
                outputs[sid] = content
                _cache_put(sid, content)
            else:
                outputs[sid] = ""

        return outputs

    # Mark every stage as running first (UI shows progress immediately).
    for stage_id, stage_name in STAGE_FLOW:
        pipeline_tracker.start_stage(stage_id)
        agent_id, task, progress = stage_agents.get(
            stage_id, ("devops", "Working", 0.0)
        )
        pipeline_tracker.update_agent(
            agent_id, "working", f"{task} for: {title}", progress, 50.0
        )
        pipeline_tracker.add_event(f"Running stage: {stage_name}", "info", stage_id)

    batch_groups = [
        ["requirement", "planning", "design"],
        ["development"],
        ["testing", "review", "deployment", "memory"],
    ]
    if not getattr(settings, "pipeline_batch_stages", True):
        batch_groups = [[sid] for sid, _ in STAGE_FLOW]

    for group in batch_groups:
        outputs = await _run_batch(group)
        for sid in group:
            content = outputs.get(sid)
            if content is None or content == "":
                all_ok = False
                _record_stage_result(sid, "Failed: no output from gateway", False)
            else:
                _record_stage_result(sid, content, True)

    # Refresh any stages still marked "running" (dispatch was skipped/failed).
    for stage_id, _ in STAGE_FLOW:
        stage = next(
            (s for s in pipeline_tracker.status.stages if s.id == stage_id), None
        )
        if stage and stage.status == "running":
            all_ok = False
            _record_stage_result(stage_id, "Failed: no output from gateway", False)

    # ── Final stage: open a proper PR with the mission's changes ───────────────
    pr_result = None
    if repo_context and mission.enabled:
        pipeline_tracker.set_phase(
            "deployment", "Opening pull request for the mission changes..."
        )
        pipeline_tracker.add_event(
            f"Preparing pull request on {target_repo} with the significant "
            "mission changes...",
            "info",
        )
        try:
            pr_result = await mission.execute_mission_and_open_pr(
                repo_full_name=target_repo,
                mission_title=title,
                mission_description=description,
                user_id=user_id,
                repo_context=repo_context,
            )
            if pr_result.get("pull_request_url"):
                pipeline_tracker.set_pull_request(
                    pr_result["pull_request_url"],
                    pr_result.get("branch_name", ""),
                )
                pipeline_tracker.add_event(
                    f"Pull request opened: {pr_result['pull_request_url']}", "info"
                )
            elif pr_result.get("no_changes_needed"):
                pipeline_tracker.add_event(
                    "No significant changes were needed for this mission.", "info"
                )
            elif pr_result.get("success") is False:
                # Commits may have landed on the branch, but GitHub rejected the
                # PR (403/422, etc.). Fail the PR stage so the mission is not
                # reported as complete without its pull request.
                all_ok = False
                pr_error = str(
                    pr_result.get("pr_error")
                    or pr_result.get("error")
                    or "GitHub rejected the pull request."
                )[:300]
                pipeline_tracker.add_event(f"PR failed: {pr_error}", "error")
                pipeline_tracker.update_stage(
                    "deployment", 50.0, f"PR failed: {pr_error}"
                )
            else:
                all_ok = False
                pr_message = str(pr_result.get("error") or "unknown reason")[:300]
                pipeline_tracker.add_event(f"PR not created: {pr_message}", "error")
                pipeline_tracker.update_stage(
                    "deployment",
                    50.0,
                    f"PR not created: {pr_message}",
                )
        except Exception as e:
            logger.exception("Mission PR step failed")
            all_ok = False
            error_msg = str(e)[:300]
            pipeline_tracker.add_event(f"PR step failed: {error_msg}", "error")
            pipeline_tracker.update_stage(
                "deployment", 50.0, f"PR step failed: {error_msg}"
            )

    pipeline_tracker.finish(success=all_ok)
    if all_ok:
        pipeline_tracker.add_event(f"Mission '{title}' completed successfully.", "info")
    else:
        pipeline_tracker.add_event(
            f"Mission '{title}' finished with some failed stages.", "info"
        )


@router.post("/missions", summary="Create a new AI mission")
async def create_mission(
    body: CreateMissionRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    """
    Creates a new mission in the Tatvik pipeline.
    A mission flows through stages: Requirement → Planning → Design → Development → Testing → Review → Deployment → Memory.

    When ``execute=true`` the mission is actually dispatched to the OpenClaw
    (Hugging Face) gateway in the background, so each stage appears in the
    HF Space logs and the pipeline advances in real time.
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
    pipeline_tracker.register_agent(
        "reviewer", "Code Reviewer", "Code review & quality gates"
    )
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
        # Dispatch the mission through the OpenClaw/HF gateway in the background
        # so every stage is logged on the HF Space and the pipeline progresses.
        # Resolve the user's GitHub token so the mission can open a PR.
        github_token = ""
        try:
            from sqlalchemy import select as sa_select

            profile = db.execute(
                sa_select(GithubProfile).where(GithubProfile.user_id == user_id)
            ).scalar_one_or_none()
            if profile and profile.access_token:
                github_token = profile.access_token
        except Exception as e:
            logger.warning(f"Could not resolve GitHub token for mission: {e}")

        background_tasks.add_task(
            _run_mission_in_background,
            body.title,
            body.description,
            body.repository,
            user_id,
            github_token,
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
async def get_pipeline_status(
    user_id: str = Depends(get_current_user_id),
):
    """
    Returns real-time status of the Tatvik pipeline:
    - Configuration (enabled/disabled state)
    - Current phase, goal, and step-level execution progress
    - Stages, agents, timeline
    - Cognee memory-layer connectivity health
    """
    report = pipeline_tracker.report()
    report["cognee_health"] = await _cognee.check_health()
    return report


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
    db: Session = Depends(get_db),
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
    started = time.perf_counter()
    try:
        result = await openclaw.execute_tool_capability(
            tool_id=body.tool_id,
            capability=body.capability,
            parameters=body.parameters,
            user_context=body.user_context,
        )

        # Persist execution history to the database
        try:
            original_prompt = (
                f"tool capability: {body.tool_id}.{body.capability} "
                f"params={body.parameters}"
            )
            history = PromptHistory(
                user_id=user_id,
                session_id=(
                    body.parameters.get("session_id")
                    if isinstance(body.parameters, dict)
                    else None
                ),
                original_prompt=original_prompt,
                refined_prompt=original_prompt,
                response=(
                    str(result.get("output", ""))[:4000]
                    if result.get("output")
                    else None
                ),
                workflow=f"openclaw.{body.tool_id}",
                project_name=(
                    body.parameters.get("repo")
                    if isinstance(body.parameters, dict)
                    else None
                ),
            )
            db.add(history)
            db.flush()
            commit = ExecutedCommand(
                session_id=f"openclaw-{body.tool_id}",
                prompt_event_id=history.id,
                command=f"{body.tool_id}.{body.capability}",
                args=json.dumps(body.parameters),
                exit_code=0 if result.get("success") else 1,
                stdout=str(result.get("output", ""))[:4000],
                duration_ms=int((time.perf_counter() - started) * 1000),
            )
            db.add(commit)
            db.commit()
        except Exception as e:
            logger.warning(f"Failed to persist openclaw execution log: {e}")
            db.rollback()

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
