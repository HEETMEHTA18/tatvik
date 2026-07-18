"""
Pipeline Status Tracker — real-time insight into what the Tatvik pipeline is doing.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any

from app.core.config import settings

logger = logging.getLogger(__name__)


@dataclass
class PipelineStepInfo:
    step: str
    status: str = "pending"
    tool_id: str = ""
    capability: str = ""
    started_at: str | None = None
    finished_at: str | None = None
    details: str = ""


@dataclass
class PipelineStage:
    id: str
    name: str
    status: str = "pending"  # pending | running | done | failed | skipped
    progress: float = 0.0  # 0.0 – 100.0
    agent_id: str = ""
    steps: list[PipelineStepInfo] = field(default_factory=list)
    started_at: str | None = None
    finished_at: str | None = None
    message: str = ""


@dataclass
class AgentStatus:
    id: str
    name: str
    role: str = ""
    status: str = "idle"  # idle | working | done | failed
    current_task: str = ""
    progress: float = 0.0
    confidence: float = 0.0
    runtime_seconds: float = 0.0
    tokens_used: int = 0
    logs: list[str] = field(default_factory=list)
    started_at: str | None = None


@dataclass
class TimelineEvent:
    timestamp: str
    type: str  # stage_started | stage_completed | agent_status | step_completed | info | error | log
    stage_id: str = ""
    agent_id: str = ""
    message: str = ""
    details: str = ""


@dataclass
class MissionMetadata:
    title: str = ""
    description: str = ""
    priority: str = "medium"  # low | medium | high | critical
    deadline: str = ""
    repository: str = ""
    status: str = "idle"  # idle | running | completed | failed | cancelled
    created_at: str = ""


@dataclass
class PipelineStatus:
    phase: str = "idle"
    started_at: str | None = None
    current_goal: str = ""
    steps: list[PipelineStepInfo] = field(default_factory=list)
    message: str = ""
    stages: list[PipelineStage] = field(default_factory=list)
    agents: list[AgentStatus] = field(default_factory=list)
    timeline: list[TimelineEvent] = field(default_factory=list)
    mission: MissionMetadata = field(default_factory=MissionMetadata)


STAGE_FLOW = [
    ("requirement", "Requirement Analysis"),
    ("planning", "Architecture Planning"),
    ("design", "UI/UX Design"),
    ("development", "Development"),
    ("testing", "Testing & QA"),
    ("review", "Code Review"),
    ("deployment", "Deployment"),
    ("memory", "Knowledge Storage"),
]


class PipelineStatusTracker:
    _instance: PipelineStatusTracker | None = None

    def __new__(cls) -> PipelineStatusTracker:
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
        self._initialized = True
        self.status = PipelineStatus()

    def start_mission(
        self,
        title: str,
        description: str = "",
        priority: str = "medium",
        deadline: str = "",
        repository: str = "",
    ):
        now = datetime.now(timezone.utc).isoformat()
        self.status = PipelineStatus(
            phase="planning",
            started_at=now,
            current_goal=title,
            message=f"Mission '{title}' initialized. Starting pipeline...",
            stages=[
                PipelineStage(
                    id=sid, name=sname, status="pending", message="Awaiting execution"
                )
                for sid, sname in STAGE_FLOW
            ],
            mission=MissionMetadata(
                title=title,
                description=description,
                priority=priority,
                deadline=deadline,
                repository=repository,
                status="running",
                created_at=now,
            ),
        )
        self._add_timeline("info", "", "", f"Mission started: {title}")

    def reset(self):
        self.status = PipelineStatus()
        self._log()

    # ── Stages ──

    def start_stage(self, stage_id: str):
        for s in self.status.stages:
            if s.id == stage_id:
                s.status = "running"
                s.started_at = datetime.now(timezone.utc).isoformat()
                s.message = "In progress..."
                self._add_timeline(
                    "stage_started", stage_id, "", f"Stage started: {s.name}"
                )
                self.status.phase = stage_id
                self._log()
                return

    def update_stage(self, stage_id: str, progress: float, message: str = ""):
        for s in self.status.stages:
            if s.id == stage_id:
                s.progress = min(progress, 100.0)
                if message:
                    s.message = message
                self._log()
                return

    def complete_stage(self, stage_id: str, success: bool = True):
        for s in self.status.stages:
            if s.id == stage_id:
                s.status = "done" if success else "failed"
                s.progress = 100.0 if success else s.progress
                s.finished_at = datetime.now(timezone.utc).isoformat()
                s.message = "Completed" if success else "Failed"
                self._add_timeline(
                    "stage_completed",
                    stage_id,
                    "",
                    f"Stage {'completed' if success else 'failed'}: {s.name}",
                )
                self._log()
                return

    def add_step_to_stage(self, stage_id: str, step: PipelineStepInfo):
        for s in self.status.stages:
            if s.id == stage_id:
                s.steps.append(step)
                self._add_timeline(
                    "step_completed", stage_id, step.tool_id, f"Step: {step.step}"
                )
                return

    # ── Agents ──

    def register_agent(self, agent_id: str, name: str, role: str = ""):
        for a in self.status.agents:
            if a.id == agent_id:
                return
        self.status.agents.append(
            AgentStatus(id=agent_id, name=name, role=role, status="idle")
        )

    def update_agent(
        self,
        agent_id: str,
        status: str = "",
        current_task: str = "",
        progress: float = -1.0,
        confidence: float = -1.0,
        log: str = "",
    ):
        for a in self.status.agents:
            if a.id == agent_id:
                if status:
                    a.status = status
                    if status == "working" and not a.started_at:
                        a.started_at = datetime.now(timezone.utc).isoformat()
                if current_task:
                    a.current_task = current_task
                if progress >= 0:
                    a.progress = progress
                if confidence >= 0:
                    a.confidence = confidence
                if log:
                    a.logs.append(log)
                    self._add_timeline("log", "", agent_id, log)
                self._log()
                return

    # ── Timeline ──

    def _add_timeline(
        self, event_type: str, stage_id: str = "", agent_id: str = "", message: str = ""
    ):
        self.status.timeline.append(
            TimelineEvent(
                timestamp=datetime.now(timezone.utc).isoformat(),
                type=event_type,
                stage_id=stage_id,
                agent_id=agent_id,
                message=message,
            )
        )

    def add_event(
        self,
        message: str,
        event_type: str = "info",
        stage_id: str = "",
        agent_id: str = "",
    ):
        self._add_timeline(event_type, stage_id, agent_id, message)

    # ── Legacy API compatibility ──

    def start_planning(self, goal: str):
        if not self.status.mission.title:
            self.start_mission(title=goal)
        self.status.phase = "planning"
        self.status.current_goal = goal
        self.status.message = "Decomposing goal into workflow steps..."
        self._add_timeline("info", "", "", f"Planning goal: {goal}")
        self._log()

    def add_step(self, info: PipelineStepInfo):
        self.status.steps.append(info)
        self._log()

    def update_step(self, index: int, status: str, details: str = ""):
        if 0 <= index < len(self.status.steps):
            s = self.status.steps[index]
            s.status = status
            s.details = details
            if status == "running":
                s.started_at = datetime.now(timezone.utc).isoformat()
            elif status in ("done", "failed"):
                s.finished_at = datetime.now(timezone.utc).isoformat()
            self._log()

    def set_phase(self, phase: str, message: str = ""):
        self.status.phase = phase
        if message:
            self.status.message = message
        self._log()

    def finish(self, success: bool):
        self.status.phase = "done" if success else "failed"
        self.status.mission.status = "completed" if success else "failed"
        self.status.message = (
            "Pipeline completed successfully." if success else "Pipeline failed."
        )
        self._add_timeline(
            "info", "", "", "Pipeline completed" if success else "Pipeline failed"
        )
        self._log()

    # ── Snapshot & Report ──

    def snapshot(self) -> dict:
        return {
            "phase": self.status.phase,
            "started_at": self.status.started_at,
            "current_goal": self.status.current_goal,
            "message": self.status.message,
            "mission": {
                "title": self.status.mission.title,
                "description": self.status.mission.description,
                "priority": self.status.mission.priority,
                "deadline": self.status.mission.deadline,
                "repository": self.status.mission.repository,
                "status": self.status.mission.status,
                "created_at": self.status.mission.created_at,
            },
            "stages": [
                {
                    "id": s.id,
                    "name": s.name,
                    "status": s.status,
                    "progress": s.progress,
                    "agent_id": s.agent_id,
                    "started_at": s.started_at,
                    "finished_at": s.finished_at,
                    "message": s.message,
                    "steps": [
                        {
                            "step": st.step,
                            "status": st.status,
                            "tool_id": st.tool_id,
                            "capability": st.capability,
                        }
                        for st in s.steps
                    ],
                }
                for s in self.status.stages
            ],
            "agents": [
                {
                    "id": a.id,
                    "name": a.name,
                    "role": a.role,
                    "status": a.status,
                    "current_task": a.current_task,
                    "progress": a.progress,
                    "confidence": a.confidence,
                    "runtime_seconds": a.runtime_seconds,
                    "tokens_used": a.tokens_used,
                    "started_at": a.started_at,
                    "logs": a.logs[-20:],
                }
                for a in self.status.agents
            ],
            "timeline": [
                {
                    "timestamp": t.timestamp,
                    "type": t.type,
                    "stage_id": t.stage_id,
                    "agent_id": t.agent_id,
                    "message": t.message,
                }
                for t in self.status.timeline[-50:]
            ],
            "steps": [
                {
                    "step": s.step,
                    "status": s.status,
                    "tool_id": s.tool_id,
                    "capability": s.capability,
                    "started_at": s.started_at,
                    "finished_at": s.finished_at,
                    "details": s.details,
                }
                for s in self.status.steps
            ],
        }

    def config_status(self) -> dict:
        return {
            "openclaw_enabled": bool(settings.openclaw_api_key),
            "openclaw_url": settings.openclaw_api_url,
            "cognee_enabled": bool(settings.cognee_api_key),
            "cognee_url": settings.cognee_base_url,
            "cognee_brain_name": settings.cognee_brain_name,
        }

    def _log(self):
        logger.debug(
            f"[PipelineStatus] phase={self.status.phase} goal='{self.status.current_goal}'"
        )

    def report(self) -> dict:
        return {
            "config": self.config_status(),
            "pipeline": self.snapshot(),
        }


pipeline_tracker = PipelineStatusTracker()
