"""
OpenClaw Execution Engine — Upgraded Universal Automation Runtime
=================================================================
Architecture Position:
  Intelligence Layer (LLMs)
        ↓
  Cognee Memory Layer
        ↓
  Tatvik Planner
        ↓
  ★ OpenClaw Execution Engine  ←── THIS FILE
        ↓
  GitHub | Notion | Slack | Docker | Vercel | AWS | ...

This file upgrades OpenClaw from "AI Browser Automation" to a
"Universal Automation Runtime for Developers."

Every external service is a Tool. Every Tool has Capabilities.
Every workflow is a sequence of Capability invocations.
"""

from __future__ import annotations

import logging
from typing import Any

import httpx
from app.core.config import settings

logger = logging.getLogger(__name__)


class OpenClawService:
    """
    OpenClaw Execution Engine.
    Dispatches tool capability calls to the OpenClaw runtime
    and handles dry-run/stub mode when no API key is configured.
    """

    def __init__(self):
        """
        Initializes OpenClaw with API credentials.
        Operates in dry-run mode when no API key is provided.
        """
        self.api_url = settings.openclaw_api_url.rstrip("/")
        self.api_key = settings.openclaw_api_key

        self.headers = {"Content-Type": "application/json"}
        if self.api_key:
            self.headers["Authorization"] = f"Bearer {self.api_key}"

        self.enabled = bool(self.api_key)

        # Force stub mode during automated tests to avoid real HTTP calls
        import sys

        if settings.environment == "testing" or "pytest" in sys.modules:
            self.enabled = False

        if not self.enabled:
            logger.warning(
                "OpenClaw API Key is not configured (or in testing mode). Running in dry-run mode."
            )

    async def warmup(self) -> bool:
        """Pings the OpenClaw health endpoint to keep the HF Space warm."""
        if not self.enabled:
            return False
        try:
            async with httpx.AsyncClient() as client:
                base = "/".join(self.api_url.split("/")[:3])
                resp = await client.get(f"{base}/health", timeout=10.0)
                return resp.status_code == 200
        except Exception:
            return False

    # ── Core dispatcher ─────────────────────────────────────────────────────

    async def _dispatch(
        self,
        prompt: str,
        timeout: float = 180.0,
        system_context: str = "",
    ) -> dict:
        """
        Low-level dispatch: sends a prompt to the OpenClaw runtime
        and returns the parsed result dict.
        """
        url = f"{self.api_url}/v1/chat/completions"
        messages = []
        if system_context:
            messages.append({"role": "system", "content": system_context})
        messages.append({"role": "user", "content": prompt})

        payload = {"model": "openclaw", "messages": messages}

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=timeout
                )
                if response.status_code == 200:
                    data = response.json()
                    content = (
                        data.get("choices", [{}])[0]
                        .get("message", {})
                        .get("content", "")
                    )
                    return {"success": True, "output": content, "raw": data}
                logger.error(
                    f"OpenClaw returned {response.status_code}: {response.text}"
                )
                return {
                    "success": False,
                    "error": "An error occurred during tool execution.",
                }
            except httpx.TimeoutException as e:
                logger.warning(f"OpenClaw dispatch timed out: {e}")
                return {
                    "success": False,
                    "error": "OpenClaw dispatch timed out.",
                }
            except Exception as e:
                logger.exception("OpenClaw dispatch failed")
                return {
                    "success": False,
                    "error": "An error occurred during tool execution.",
                }

    def _stub(self, tool_id: str, capability: str, params: dict) -> dict:
        """Returns a stub response for dry-run mode."""
        logger.info(f"[Stub] {tool_id}.{capability}({params})")
        return {
            "success": True,
            "stub": True,
            "tool_id": tool_id,
            "capability": capability,
            "message": f"Dry-run: {tool_id}.{capability} would execute with params {params}",
        }

    # ── Universal Tool Capability Executor ──────────────────────────────────

    async def execute_tool_capability(
        self,
        tool_id: str,
        capability: str,
        parameters: dict[str, Any],
        user_context: str = "",
    ) -> dict:
        """
        Execute any registered tool capability via OpenClaw.
        This is the primary method called by the Tatvik Planner.

        Args:
            tool_id: The tool to invoke (e.g. "github", "slack", "docker")
            capability: The specific capability (e.g. "create_pr", "post_message")
            parameters: Parameters for this capability
            user_context: Optional context string to enrich the prompt
        """
        if not self.enabled:
            return self._stub(tool_id, capability, parameters)

        system_context = (
            "You are the OpenClaw Execution Engine — the universal automation runtime "
            "of the Tatvik AI Operating System. You execute developer tool capabilities "
            "precisely and return structured results. "
            + (f"User context: {user_context}" if user_context else "")
        )

        param_str = "\n".join(f"  {k}: {v}" for k, v in parameters.items())
        prompt = (
            f"Execute the following tool capability:\n\n"
            f"Tool: {tool_id}\n"
            f"Capability: {capability}\n"
            f"Parameters:\n{param_str}\n\n"
            "Complete this action using all available plugins (browser, file-transfer, "
            "memory-core, canvas, device-pair, phone-control, talk-voice). "
            "Return a structured JSON result with 'success', 'output', and any relevant metadata."
        )

        return await self._dispatch(
            prompt, timeout=180.0, system_context=system_context
        )

    # ── GitHub Tool ──────────────────────────────────────────────────────────

    async def github_create_pr(
        self, repo: str, title: str, body: str, base: str = "main", head: str = "dev"
    ) -> dict:
        """Create a pull request on GitHub."""
        return await self.execute_tool_capability(
            "github",
            "create_pr",
            {"repo": repo, "title": title, "body": body, "base": base, "head": head},
        )

    async def github_review_code(self, repo: str, pr_number: int) -> dict:
        """AI-powered code review on a GitHub PR."""
        return await self.execute_tool_capability(
            "github",
            "review_code",
            {"repo": repo, "pr_number": pr_number},
        )

    async def github_create_release(self, repo: str, tag: str, notes: str) -> dict:
        """Create a tagged release on GitHub."""
        return await self.execute_tool_capability(
            "github",
            "create_release",
            {"repo": repo, "tag": tag, "notes": notes},
        )

    async def github_trigger_action(
        self, repo: str, workflow_id: str, inputs: dict | None = None
    ) -> dict:
        """Trigger a GitHub Actions workflow."""
        return await self.execute_tool_capability(
            "github",
            "trigger_action",
            {"repo": repo, "workflow_id": workflow_id, "inputs": inputs or {}},
        )

    # ── Slack Tool ───────────────────────────────────────────────────────────

    async def slack_post_message(self, channel: str, message: str) -> dict:
        """Post a message to a Slack channel."""
        return await self.execute_tool_capability(
            "slack",
            "post_message",
            {"channel": channel, "message": message},
        )

    async def slack_post_release_notes(
        self, channel: str, version: str, notes: str
    ) -> dict:
        """Post formatted release notes to Slack."""
        return await self.execute_tool_capability(
            "slack",
            "post_release_notes",
            {"channel": channel, "version": version, "notes": notes},
        )

    async def slack_daily_summary(self, channel: str, context: str) -> dict:
        """Generate and post a daily standup summary."""
        return await self.execute_tool_capability(
            "slack",
            "daily_summary",
            {"channel": channel, "context": context},
        )

    # ── Notion Tool ──────────────────────────────────────────────────────────

    async def notion_create_doc(
        self, title: str, content: str, parent_id: str = ""
    ) -> dict:
        """Create a Notion page with the given content."""
        return await self.execute_tool_capability(
            "notion",
            "create_doc",
            {"title": title, "content": content, "parent_id": parent_id},
        )

    async def notion_create_meeting_notes(self, title: str, transcript: str) -> dict:
        """Generate and save structured meeting notes to Notion."""
        return await self.execute_tool_capability(
            "notion",
            "create_meeting_notes",
            {"title": title, "transcript": transcript},
        )

    async def notion_search(self, query: str) -> dict:
        """Search across a Notion workspace."""
        return await self.execute_tool_capability(
            "notion",
            "search_knowledge_base",
            {"query": query},
        )

    # ── Jira Tool ────────────────────────────────────────────────────────────

    async def jira_read_sprint(self, project_key: str) -> dict:
        """Read the active sprint for a Jira project."""
        return await self.execute_tool_capability(
            "jira",
            "read_sprint",
            {"project_key": project_key},
        )

    async def jira_find_blockers(self, project_key: str) -> dict:
        """Identify blockers in the current sprint."""
        return await self.execute_tool_capability(
            "jira",
            "find_blockers",
            {"project_key": project_key},
        )

    async def jira_generate_sprint_summary(self, project_key: str) -> dict:
        """Generate an AI sprint summary with velocity forecast."""
        return await self.execute_tool_capability(
            "jira",
            "generate_sprint_summary",
            {"project_key": project_key},
        )

    # ── Docker Tool ──────────────────────────────────────────────────────────

    async def docker_build_and_run(
        self, dockerfile_path: str, tag: str, env_vars: dict | None = None
    ) -> dict:
        """Build a Docker image and run the container."""
        build_result = await self.execute_tool_capability(
            "docker",
            "build_image",
            {"dockerfile_path": dockerfile_path, "tag": tag},
        )
        if not build_result.get("success"):
            return build_result
        return await self.execute_tool_capability(
            "docker",
            "run_container",
            {"image": tag, "env_vars": env_vars or {}, "ports": {}},
        )

    async def docker_view_logs(self, container_name: str, lines: int = 100) -> dict:
        """Tail logs from a running Docker container."""
        return await self.execute_tool_capability(
            "docker",
            "view_logs",
            {"container_name": container_name, "lines": lines},
        )

    # ── Vercel Tool ──────────────────────────────────────────────────────────

    async def vercel_deploy(self, repo: str, branch: str = "main") -> dict:
        """Deploy a Vercel project from a branch."""
        return await self.execute_tool_capability(
            "vercel",
            "deploy_preview",
            {"repo": repo, "branch": branch},
        )

    async def vercel_promote_production(self, deployment_id: str) -> dict:
        """Promote a Vercel preview deployment to production."""
        return await self.execute_tool_capability(
            "vercel",
            "deploy_production",
            {"deployment_id": deployment_id},
        )

    # ── Figma Tool ───────────────────────────────────────────────────────────

    async def figma_design_to_code(
        self, file_key: str, frame_id: str, repo: str
    ) -> dict:
        """Read Figma design, generate React code, and open a PR."""
        code_result = await self.execute_tool_capability(
            "figma",
            "generate_react_code",
            {"file_key": file_key, "frame_id": frame_id},
        )
        if not code_result.get("success"):
            return code_result
        return await self.execute_tool_capability(
            "figma",
            "create_pr_from_design",
            {"file_key": file_key, "repo": repo},
        )

    # ── Gmail Tool ───────────────────────────────────────────────────────────

    async def gmail_process_inbox(
        self, query: str = "is:unread", limit: int = 10
    ) -> dict:
        """Read, summarize, and create tasks from emails."""
        emails = await self.execute_tool_capability(
            "gmail",
            "read_emails",
            {"query": query, "limit": limit},
        )
        if not emails.get("success"):
            return emails
        return await self.execute_tool_capability(
            "gmail",
            "summarize",
            {"message_ids": emails.get("output", "")},
        )

    # ── Legacy API: kept for backward compatibility ──────────────────────────

    async def execute_task(
        self, repo_url: str, task_description: str, branch_name: str | None = None
    ) -> dict:
        """
        Legacy method: Execute a development task on a repository.
        Kept for backward compatibility — delegates to execute_tool_capability.
        """
        if not self.enabled:
            return {
                "success": True,
                "stub": True,
                "message": "OpenClaw dry-run: task would execute on " + repo_url,
                "pull_request_url": "https://github.com/stub-owner/stub-repo/pull/1",
            }

        branch_text = f" (branch: {branch_name})" if branch_name else ""
        prompt = (
            f"Repository: {repo_url}{branch_text}\n"
            f"Task: {task_description}\n\n"
            "Clone or fetch the code, analyze the architecture, dependencies, and code quality, "
            "then execute the task. Use all available plugins to complete this thoroughly."
        )
        result = await self._dispatch(prompt, timeout=180.0)
        if result.get("success"):
            result["pull_request_url"] = f"{repo_url}/pulls"
        return result

    async def run_terminal_command(self, command: str) -> dict:
        """
        Legacy method: Run a terminal command inside the OpenClaw sandbox.
        """
        if not command or not command.strip():
            return {"success": False, "error": "Invalid command: must be non-empty"}

        if not self.enabled:
            return {
                "success": True,
                "stub": True,
                "output": f"Mock output for: {command}",
            }

        result = await self._dispatch(
            f"Run the following terminal command and return its exact output:\n\n{command}",
            timeout=180.0,
        )
        if result.get("success"):
            result["output"] = result.pop("output", "")
        return result

    async def test_ui_with_browser(self, target_url: str, ui_instructions: str) -> dict:
        """
        Legacy method: Use browser plugin to evaluate a live UI.
        """
        if not self.enabled:
            return {
                "success": True,
                "stub": True,
                "message": f"Mock UI review for {target_url}",
            }

        return await self.execute_tool_capability(
            "browser",
            "run_ui_test",
            {"url": target_url, "instructions": ui_instructions},
        )

    async def test_mobile_app(self, ngrok_url: str, test_instructions: str) -> dict:
        """
        Legacy method: Use device-pair and phone-control plugins for mobile testing.
        """
        if not self.enabled:
            return {
                "success": True,
                "stub": True,
                "message": f"Mock mobile test for {ngrok_url}",
            }

        prompt = (
            f"Use your 'device-pair' plugin to connect to the ADB server at {ngrok_url}. "
            f"Then use 'phone-control' to perform: {test_instructions}"
        )
        return await self._dispatch(prompt, timeout=300.0)

    async def start_voice_mentor_stream(self, context_prompt: str) -> dict:
        """
        Legacy method: Initialize a WebRTC/WebSocket voice stream.
        """
        if not self.enabled:
            return {
                "success": True,
                "stub": True,
                "stream_url": "wss://mock-stream.openclaw.ai",
            }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    f"{self.api_url}/v1/voice/stream/init",
                    headers=self.headers,
                    json={
                        "model": "openclaw",
                        "system_instruction": (
                            f"You are Tatvik Voice. Use 'memory-core' to remember user details. "
                            f"Context: {context_prompt}"
                        ),
                    },
                    timeout=10.0,
                )
                if response.status_code == 200:
                    return {
                        "success": True,
                        "stream_url": response.json().get("stream_url"),
                    }
                return {"success": False, "error": "Failed to initialize voice stream."}
            except Exception as e:
                logger.exception("Failed to initialize voice stream")
                return {"success": False, "error": "Failed to initialize voice stream."}
