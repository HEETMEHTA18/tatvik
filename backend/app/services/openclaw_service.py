import httpx
import logging
from app.core.config import settings

logger = logging.getLogger(__name__)


class OpenClawService:
    def __init__(self):
        """
        Initializes OpenClaw Service with API credentials and target runtime URLs.
        """
        self.api_url = settings.openclaw_api_url
        self.api_key = settings.openclaw_api_key

        self.headers = {"Content-Type": "application/json"}
        if self.api_key:
            self.headers["Authorization"] = f"Bearer {self.api_key}"

        self.enabled = bool(self.api_key)
        if not self.enabled:
            logger.warning(
                "OpenClaw API Key is not configured. OpenClaw execution will run in dry-run mode."
            )

    async def execute_task(
        self, repo_url: str, task_description: str, branch_name: str = "main"
    ) -> dict:
        """
        Triggers OpenClaw to carry out a developmental task (e.g. coding features, writing tests, applying bug fixes)
        inside its sandboxed environment, then push changes to GitHub.
        """
        if not self.enabled:
            logger.info(
                f"[Stub] Executing task '{task_description}' on {repo_url} (branch: {branch_name})"
            )
            return {
                "success": True,
                "stub": True,
                "message": "OpenClaw API key not configured. Mock execution successful.",
                "pull_request_url": "https://github.com/stub-owner/stub-repo/pull/1",
            }

        url = f"{self.api_url}/tasks/execute"
        payload = {
            "repo_url": repo_url,
            "task": task_description,
            "branch": branch_name,
            "github_token": getattr(
                settings, "github_client_secret", ""
            ),  # Passed for GitHub PR authorization
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=120.0
                )
                if response.status_code == 200:
                    return response.json()
                else:
                    logger.error(
                        f"OpenClaw returned error status {response.status_code}: {response.text}"
                    )
                    return {"success": False, "error": response.text}
            except Exception as e:
                logger.exception(
                    "Failed to dispatch task execution request to OpenClaw"
                )
                return {"success": False, "error": str(e)}

    async def run_terminal_command(self, command: str) -> dict:
        """
        Instructs OpenClaw to run a verification terminal command inside its secure execution environment.
        """
        if not self.enabled:
            logger.info(f"[Stub] Running terminal command: {command}")
            return {
                "success": True,
                "stub": True,
                "output": f"Mock output for: {command}",
            }

        url = f"{self.api_url}/terminal/run"
        payload = {"command": command}

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=30.0
                )
                if response.status_code == 200:
                    return response.json()
                else:
                    logger.error(
                        f"OpenClaw command execution returned error: {response.text}"
                    )
                    return {"success": False, "error": response.text}
            except Exception as e:
                logger.exception("Failed to dispatch command run request to OpenClaw")
                return {"success": False, "error": str(e)}
