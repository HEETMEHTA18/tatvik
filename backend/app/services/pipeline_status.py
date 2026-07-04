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
    status: str       # pending | running | done | failed
    tool_id: str = ""
    capability: str = ""
    started_at: str | None = None
    finished_at: str | None = None
    details: str = ""


@dataclass
class PipelineStatus:
    phase: str = "idle"  # idle | planning | executing_cognee | executing_openclaw | done | failed
    started_at: str | None = None
    current_goal: str = ""
    steps: list[PipelineStepInfo] = field(default_factory=list)
    message: str = ""


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

    def start_planning(self, goal: str):
        self.status = PipelineStatus(
            phase="planning",
            started_at=datetime.now(timezone.utc).isoformat(),
            current_goal=goal,
            steps=[],
            message="Decomposing goal into workflow steps...",
        )
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
        self.status.message = "Pipeline completed successfully." if success else "Pipeline failed."
        self._log()

    def reset(self):
        self.status = PipelineStatus()
        self._log()

    def snapshot(self) -> dict:
        return {
            "phase": self.status.phase,
            "started_at": self.status.started_at,
            "current_goal": self.status.current_goal,
            "message": self.status.message,
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
        }

    def _log(self):
        logger.debug(f"[PipelineStatus] phase={self.status.phase} goal='{self.status.current_goal}'")

    def report(self) -> dict:
        return {
            "config": self.config_status(),
            "pipeline": self.snapshot(),
        }


pipeline_tracker = PipelineStatusTracker()
