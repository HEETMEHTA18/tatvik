"""
Tatvik Planner — Decision & Goal Decomposition Layer
======================================================
The Planner sits between the LLM Intelligence Layer and the OpenClaw
Execution Engine. It:
  1. Takes a high-level user goal ("Ship version 3.2")
  2. Queries Cognee memory for context
  3. Decomposes the goal into an ordered list of Tool calls (a Workflow)
  4. Returns the plan to OpenClaw for sequential execution
  5. Stores the execution result back into Cognee memory
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

import httpx
from app.core.config import settings
from app.services.openclaw_tools import get_all_tools_summary, get_architecture_stats

logger = logging.getLogger(__name__)


@dataclass
class WorkflowStep:
    """A single executable step in a Tatvik Workflow."""
    step_number: int
    tool_id: str
    capability: str
    parameters: dict[str, Any]
    description: str
    depends_on: list[int] = field(default_factory=list)
    status: str = "pending"   # pending | running | done | failed
    result: dict | None = None


@dataclass
class TatvikWorkflow:
    """A fully-planned, ordered list of steps to achieve a user goal."""
    goal: str
    user_id: str
    steps: list[WorkflowStep]
    created_at: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    status: str = "planned"   # planned | running | completed | failed
    memory_context: list[str] = field(default_factory=list)


class TatvikPlanner:
    """
    Uses the configured LLM to decompose a user goal into an executable
    workflow of OpenClaw tool calls, enriched with Cognee memory context.
    """

    # ── Common workflow templates (no LLM call needed for known patterns) ──

    WORKFLOW_TEMPLATES: dict[str, list[dict]] = {
        "ship_release": [
            {"tool_id": "github", "capability": "list_commits", "description": "Read recent commits since last release"},
            {"tool_id": "jira", "capability": "read_sprint", "description": "Check sprint status and blockers"},
            {"tool_id": "notion", "capability": "search_knowledge_base", "description": "Pull release checklist from Notion"},
            {"tool_id": "github", "capability": "trigger_action", "description": "Run test suite via GitHub Actions"},
            {"tool_id": "github", "capability": "create_release", "description": "Create GitHub release + tag"},
            {"tool_id": "notion", "capability": "create_doc", "description": "Write release notes to Notion"},
            {"tool_id": "vercel", "capability": "deploy_production", "description": "Deploy to Vercel production"},
            {"tool_id": "slack", "capability": "post_release_notes", "description": "Broadcast release notes to Slack"},
            {"tool_id": "cognee_memory", "capability": "store_memory", "description": "Store release record in memory"},
        ],
        "review_pr": [
            {"tool_id": "github", "capability": "review_code", "description": "AI code review on the PR"},
            {"tool_id": "cognee_memory", "capability": "recall", "description": "Recall past bugs in similar code"},
            {"tool_id": "github", "capability": "create_issue", "description": "File issues for critical findings"},
            {"tool_id": "notion", "capability": "update_roadmap", "description": "Log review outcome to Notion"},
            {"tool_id": "slack", "capability": "notify_team", "description": "Notify reviewer via Slack"},
        ],
        "sprint_planning": [
            {"tool_id": "jira", "capability": "read_sprint", "description": "Read current sprint backlog"},
            {"tool_id": "cognee_memory", "capability": "recall", "description": "Recall velocity from past sprints"},
            {"tool_id": "google_calendar", "capability": "get_upcoming", "description": "Check team calendar for deadlines"},
            {"tool_id": "jira", "capability": "estimate_difficulty", "description": "AI difficulty estimation for backlog"},
            {"tool_id": "jira", "capability": "assign_task", "description": "Assign tasks based on skill graph"},
            {"tool_id": "notion", "capability": "update_sprint", "description": "Sync sprint plan to Notion"},
            {"tool_id": "slack", "capability": "post_message", "description": "Share sprint plan with team"},
        ],
        "process_meeting": [
            {"tool_id": "cognee_memory", "capability": "recall", "description": "Recall context for meeting participants"},
            {"tool_id": "notion", "capability": "create_meeting_notes", "description": "Create structured Notion meeting notes"},
            {"tool_id": "linear", "capability": "create_issue", "description": "Create action-item issues in Linear"},
            {"tool_id": "notion", "capability": "update_roadmap", "description": "Update roadmap from meeting decisions"},
            {"tool_id": "slack", "capability": "post_message", "description": "Send meeting summary to Slack"},
            {"tool_id": "cognee_memory", "capability": "store_memory", "description": "Store decisions in knowledge graph"},
        ],
        "deploy_feature": [
            {"tool_id": "github", "capability": "review_code", "description": "Run final AI review before deploy"},
            {"tool_id": "github", "capability": "merge_pr", "description": "Merge the feature PR"},
            {"tool_id": "github", "capability": "trigger_action", "description": "Run CI/CD pipeline"},
            {"tool_id": "vercel", "capability": "deploy_preview", "description": "Deploy preview environment"},
            {"tool_id": "browser", "capability": "run_ui_test", "description": "Automated UI smoke test"},
            {"tool_id": "vercel", "capability": "deploy_production", "description": "Promote to production"},
            {"tool_id": "notion", "capability": "create_doc", "description": "Document the feature in Notion"},
            {"tool_id": "slack", "capability": "notify_team", "description": "Notify team of deployment"},
        ],
        "onboard_new_dev": [
            {"tool_id": "github", "capability": "clone_repo", "description": "Clone main repository"},
            {"tool_id": "cognee_memory", "capability": "recall", "description": "Retrieve onboarding guide from memory"},
            {"tool_id": "notion", "capability": "search_knowledge_base", "description": "Pull architecture docs from Notion"},
            {"tool_id": "jira", "capability": "read_sprint", "description": "Show current sprint to new dev"},
            {"tool_id": "slack", "capability": "notify_team", "description": "Introduce new dev to the team"},
        ],
    }

    def __init__(self):
        self.llm_url = settings.openclaw_api_url
        self.llm_key = settings.openclaw_api_key
        self.tools_summary = get_all_tools_summary()

    def _match_template(self, goal: str) -> list[dict] | None:
        """Fast path: match goal text to a known workflow template."""
        goal_lower = goal.lower()
        if any(kw in goal_lower for kw in ["ship", "release", "deploy version"]):
            return self.WORKFLOW_TEMPLATES["ship_release"]
        if any(kw in goal_lower for kw in ["review pr", "review pull request", "code review"]):
            return self.WORKFLOW_TEMPLATES["review_pr"]
        if any(kw in goal_lower for kw in ["sprint", "planning", "plan sprint"]):
            return self.WORKFLOW_TEMPLATES["sprint_planning"]
        if any(kw in goal_lower for kw in ["meeting", "transcript", "standup"]):
            return self.WORKFLOW_TEMPLATES["process_meeting"]
        if any(kw in goal_lower for kw in ["deploy feature", "merge feature", "ship feature"]):
            return self.WORKFLOW_TEMPLATES["deploy_feature"]
        if any(kw in goal_lower for kw in ["onboard", "new developer", "new dev"]):
            return self.WORKFLOW_TEMPLATES["onboard_new_dev"]
        return None

    async def plan_workflow(
        self, goal: str, user_id: str, memory_context: list[str] | None = None
    ) -> TatvikWorkflow:
        """
        Main planning method. Returns a structured TatvikWorkflow.
        1. Tries template matching first (fast path)
        2. Falls back to LLM decomposition (slow path)
        """
        logger.info(f"[Tatvik Planner] Planning workflow for goal: '{goal}' (user={user_id})")
        context = memory_context or []

        # Fast path: template matching
        template_steps = self._match_template(goal)
        if template_steps:
            logger.info(f"[Tatvik Planner] Matched template for goal '{goal}'")
            steps = [
                WorkflowStep(
                    step_number=i + 1,
                    tool_id=s["tool_id"],
                    capability=s["capability"],
                    parameters={},
                    description=s["description"],
                )
                for i, s in enumerate(template_steps)
            ]
            return TatvikWorkflow(
                goal=goal,
                user_id=user_id,
                steps=steps,
                memory_context=context,
            )

        # Slow path: LLM decomposition
        if self.llm_key:
            try:
                steps = await self._llm_decompose(goal, context)
                return TatvikWorkflow(goal=goal, user_id=user_id, steps=steps, memory_context=context)
            except Exception as e:
                logger.warning(f"[Tatvik Planner] LLM decomposition failed: {e}. Using fallback plan.")

        # Fallback: single-step generic execution
        return TatvikWorkflow(
            goal=goal,
            user_id=user_id,
            steps=[
                WorkflowStep(
                    step_number=1,
                    tool_id="cognee_memory",
                    capability="recall",
                    parameters={"query": goal},
                    description=f"Recall relevant context for: {goal}",
                )
            ],
            memory_context=context,
        )

    async def _llm_decompose(self, goal: str, context: list[str]) -> list[WorkflowStep]:
        """
        Calls the configured LLM to decompose a natural-language goal into
        structured tool calls, using the Tool Registry as context.
        """
        tool_descriptions = "\n".join(
            f"- {t['id']}: {t['description']} | Capabilities: {', '.join(t['capabilities'])}"
            for t in self.tools_summary
        )

        context_text = "\n".join(context) if context else "No prior context available."

        system_prompt = (
            "You are the Tatvik Planner — the decision layer of the Tatvik AI OS. "
            "Your job is to decompose a user's high-level goal into an ordered list of "
            "concrete tool actions. Each step must reference a valid tool_id and capability "
            "from the tool registry. Respond ONLY with a JSON array of steps.\n\n"
            f"Available Tools:\n{tool_descriptions}"
        )

        user_message = (
            f"Memory Context:\n{context_text}\n\n"
            f"Goal: {goal}\n\n"
            "Respond with a JSON array. Each item: "
            '{"tool_id": "...", "capability": "...", "description": "...", "parameters": {}}'
        )

        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.llm_url}/chat/completions",
                headers={"Authorization": f"Bearer {self.llm_key}", "Content-Type": "application/json"},
                json={
                    "model": "openclaw",
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_message},
                    ],
                    "temperature": 0.2,
                },
                timeout=30.0,
            )
            response.raise_for_status()
            content = response.json()["choices"][0]["message"]["content"]

        import json, re
        match = re.search(r"\[.*?\]", content, re.DOTALL)
        raw_steps: list[dict] = json.loads(match.group(0)) if match else []

        return [
            WorkflowStep(
                step_number=i + 1,
                tool_id=s.get("tool_id", "cognee_memory"),
                capability=s.get("capability", "recall"),
                parameters=s.get("parameters", {}),
                description=s.get("description", ""),
            )
            for i, s in enumerate(raw_steps)
        ]

    def workflow_to_dict(self, wf: TatvikWorkflow) -> dict:
        """Serializes a TatvikWorkflow to a JSON-safe dict."""
        return {
            "goal": wf.goal,
            "user_id": wf.user_id,
            "status": wf.status,
            "created_at": wf.created_at,
            "memory_context": wf.memory_context,
            "steps": [
                {
                    "step_number": s.step_number,
                    "tool_id": s.tool_id,
                    "capability": s.capability,
                    "parameters": s.parameters,
                    "description": s.description,
                    "depends_on": s.depends_on,
                    "status": s.status,
                    "result": s.result,
                }
                for s in wf.steps
            ],
        }
