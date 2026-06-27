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
        self, repo_url: str, task_description: str, branch_name: str | None = None
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

        branch_text = f" (branch: {branch_name})" if branch_name else ""
        url = f"{self.api_url}/v1/chat/completions"
        payload = {
            "model": "openclaw",
            "messages": [
                {
                    "role": "user",
                    "content": f"Repository: {repo_url}{branch_text}\nTask: {task_description}\nPlease clone or fetch the code, analyze the architecture, dependencies, and code quality, and provide a comprehensive raw analysis. You may use all 7 of your available plugins (browser, canvas, device-pair, file-transfer, memory-core, phone-control, talk-voice) to complete this task thoroughly.",
                }
            ],
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=80.0
                )
                if response.status_code == 200:
                    data = response.json()
                    message_content = (
                        data.get("choices", [{}])[0]
                        .get("message", {})
                        .get("content", "")
                    )
                    return {"success": True, "message": message_content}
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

        url = f"{self.api_url}/v1/chat/completions"
        payload = {
            "model": "openclaw",
            "messages": [
                {
                    "role": "user",
                    "content": f"Please run the following terminal command and return its output: {command}"
                }
            ]
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=80.0
                )
                if response.status_code == 200:
                    data = response.json()
                    message_content = (
                        data.get("choices", [{}])[0]
                        .get("message", {})
                        .get("content", "")
                    )
                    return {"success": True, "output": message_content}
                else:
                    logger.error(
                        f"OpenClaw command execution returned error: {response.text}"
                    )
                    return {"success": False, "error": response.text}
            except Exception as e:
                logger.exception("Failed to dispatch command run request to OpenClaw")
                return {"success": False, "error": str(e)}

    async def test_ui_with_browser(self, target_url: str, ui_instructions: str) -> dict:
        """
        Explicitly invokes the 'browser' and 'canvas' plugins to evaluate a live UI.
        """
        if not self.enabled:
            return {
                "success": True,
                "stub": True,
                "message": f"Mock UI review for {target_url}",
            }

        url = f"{self.api_url}/v1/chat/completions"
        payload = {
            "model": "openclaw",
            "messages": [
                {
                    "role": "user",
                    "content": f"Please use your 'browser' plugin to navigate to {target_url}. Then use your 'canvas' plugin to take screenshots and critique the UI. Task: {ui_instructions}",
                }
            ],
        }
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=120.0
                )
                if response.status_code == 200:
                    return {
                        "success": True,
                        "message": response.json()["choices"][0]["message"]["content"],
                    }
                return {"success": False, "error": response.text}
            except Exception as e:
                return {"success": False, "error": str(e)}

    async def test_mobile_app(self, ngrok_url: str, test_instructions: str) -> dict:
        """
        Explicitly invokes 'device-pair' and 'phone-control' plugins to test a mobile emulator over a tunnel.
        """
        if not self.enabled:
            return {
                "success": True,
                "stub": True,
                "message": f"Mock Mobile test for {ngrok_url}",
            }

        url = f"{self.api_url}/v1/chat/completions"
        payload = {
            "model": "openclaw",
            "messages": [
                {
                    "role": "user",
                    "content": f"Please use your 'device-pair' plugin to connect to the ADB server at {ngrok_url}. Then use your 'phone-control' plugin to perform this test: {test_instructions}",
                }
            ],
        }
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=300.0
                )
                if response.status_code == 200:
                    return {
                        "success": True,
                        "message": response.json()["choices"][0]["message"]["content"],
                    }
                return {"success": False, "error": response.text}
            except Exception as e:
                return {"success": False, "error": str(e)}

    async def start_voice_mentor_stream(self, context_prompt: str) -> dict:
        """
        Initializes a WebRTC/WebSocket context for 'talk-voice' and 'memory-core'.
        Returns the websocket stream URL for the Flutter app to connect to.
        """
        if not self.enabled:
            return {
                "success": True,
                "stub": True,
                "stream_url": "wss://mock-stream.openclaw.ai",
            }

        url = f"{self.api_url}/v1/voice/stream/init"
        payload = {
            "model": "openclaw",
            "system_instruction": f"You are Tatvik Voice. Use 'memory-core' to remember user details. Context: {context_prompt}",
        }
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=10.0
                )
                if response.status_code == 200:
                    return {
                        "success": True,
                        "stream_url": response.json().get("stream_url"),
                    }
                return {"success": False, "error": response.text}
            except Exception as e:
                return {"success": False, "error": str(e)}
