"""
GitHub Agent Service
====================
Uses the GitHub REST API + Gemini AI to actually perform coding tasks:
- Edit / create files in any repository
- Commit changes on a branch
- Open Pull Requests
- Read file contents

This is the real "agentic coding" layer that executes user requests.
OpenClaw on Hugging Face is the gateway for the desktop client.
For server-side agentic code actions, we use the GitHub API directly.
"""

import base64
import logging
import re

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

GITHUB_API = "https://api.github.com"


class GithubAgentService:
    """
    Performs real agentic coding operations on GitHub repositories
    using the authenticated user's GitHub OAuth token.
    """

    def __init__(self, github_token: str):
        self.token = github_token
        self.headers = {
            "Authorization": f"token {github_token}",
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "Tatvik-AI-Agent",
        }
        self.enabled = bool(github_token)

    # ──────────────────────────────────────────────
    # INTERNAL HELPERS
    # ──────────────────────────────────────────────

    async def _get_file(self, owner: str, repo: str, path: str, ref: str = "main"):
        """Fetch a file's content and SHA from GitHub."""
        url = f"{GITHUB_API}/repos/{owner}/{repo}/contents/{path}"
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                url, headers=self.headers, params={"ref": ref}, timeout=15.0
            )
            if resp.status_code == 200:
                data = resp.json()
                content = base64.b64decode(data["content"]).decode("utf-8")
                return {"content": content, "sha": data["sha"], "found": True}
            elif resp.status_code == 404:
                return {"content": "", "sha": None, "found": False}
            else:
                logger.error(f"GitHub get file error {resp.status_code}: {resp.text}")
                return None

    async def _put_file(
        self,
        owner: str,
        repo: str,
        path: str,
        content: str,
        message: str,
        sha: str = None,
        branch: str = "main",
    ):
        """Create or update a file on GitHub."""
        url = f"{GITHUB_API}/repos/{owner}/{repo}/contents/{path}"
        encoded = base64.b64encode(content.encode("utf-8")).decode("utf-8")
        payload = {"message": message, "content": encoded, "branch": branch}
        if sha:
            payload["sha"] = sha  # required for updates
        async with httpx.AsyncClient() as client:
            resp = await client.put(
                url, headers=self.headers, json=payload, timeout=15.0
            )
            if resp.status_code in (200, 201):
                data = resp.json()
                return {
                    "success": True,
                    "commit_sha": data["commit"]["sha"],
                    "file_url": data["content"]["html_url"],
                }
            else:
                logger.error(f"GitHub put file error {resp.status_code}: {resp.text}")
                return {"success": False, "error": "Failed to write file to GitHub."}

    async def _get_default_branch(self, owner: str, repo: str) -> str:
        """Get default branch name of a repository."""
        url = f"{GITHUB_API}/repos/{owner}/{repo}"
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, headers=self.headers, timeout=10.0)
            if resp.status_code == 200:
                return resp.json().get("default_branch", "main")
        return "main"

    async def _create_branch(
        self, owner: str, repo: str, branch: str, from_branch: str = "main"
    ):
        """Create a new branch from another branch."""
        # Get SHA of from_branch
        ref_url = f"{GITHUB_API}/repos/{owner}/{repo}/git/refs/heads/{from_branch}"
        async with httpx.AsyncClient() as client:
            ref_resp = await client.get(ref_url, headers=self.headers, timeout=10.0)
            if ref_resp.status_code != 200:
                return False
            sha = ref_resp.json()["object"]["sha"]

            create_url = f"{GITHUB_API}/repos/{owner}/{repo}/git/refs"
            create_resp = await client.post(
                create_url,
                headers=self.headers,
                json={"ref": f"refs/heads/{branch}", "sha": sha},
                timeout=10.0,
            )
            return create_resp.status_code in (200, 201)

    async def _create_pr(
        self,
        owner: str,
        repo: str,
        title: str,
        body: str,
        head: str,
        base: str = "main",
    ):
        """Open a Pull Request on GitHub."""
        url = f"{GITHUB_API}/repos/{owner}/{repo}/pulls"
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                url,
                headers=self.headers,
                json={"title": title, "body": body, "head": head, "base": base},
                timeout=15.0,
            )
            if resp.status_code == 201:
                return {"success": True, "pr_url": resp.json()["html_url"]}
            else:
                logger.error(f"GitHub PR error {resp.status_code}: {resp.text}")
                return {
                    "success": False,
                    "error": "Failed to create pull request on GitHub.",
                }

    async def _ai_generate_content(
        self, task: str, existing_content: str = "", file_path: str = ""
    ) -> str:
        """Use OpenClaw or NVIDIA to generate file content for a coding task."""
        from app.services.openclaw_service import OpenClawService

        openclaw = OpenClawService()

        if not openclaw.enabled and not settings.nvidia_api_key:
            return f"# AI-generated content\n# Task: {task}\n"

        prompt = (
            f"You are an expert developer. Perform this task precisely.\n\n"
            f"Task: {task}\n"
            f"File: {file_path}\n"
            f"Existing file content:\n```\n{existing_content[:3000]}\n```\n\n"
            f"Return ONLY the complete new file content. "
            f"No explanation, no markdown code fences, no preamble. "
            f"Just the raw file content that should be written to the file."
        )

        if openclaw.enabled:
            url = f"{openclaw.api_url}/v1/chat/completions"
            headers = openclaw.headers
            model_name = "openclaw"
        else:
            url = "https://integrate.api.nvidia.com/v1/chat/completions"
            headers = {
                "Authorization": f"Bearer {settings.nvidia_api_key}",
                "Content-Type": "application/json",
            }
            model_name = "meta/llama-3.3-70b-instruct"

        async with httpx.AsyncClient() as client:
            try:
                resp = await client.post(
                    url,
                    json={
                        "model": model_name,
                        "messages": [{"role": "user", "content": prompt}],
                    },
                    headers=headers,
                    timeout=60.0,
                )
                if resp.status_code == 200:
                    return (
                        resp.json()["choices"][0]["message"]["content"]
                        .replace("```python", "")
                        .replace("```dart", "")
                        .replace("```html", "")
                        .replace("```", "")
                        .strip()
                    )
                else:
                    logger.error(f"AI content generation error: {resp.text}")
            except Exception as e:
                logger.warning(f"AI content generation failed: {e}")
        return f"# Task: {task}\n# (AI generation failed — please implement manually)\n"

    def _parse_owner_repo(self, repo_full_name: str):
        """Parse 'owner/repo' string into tuple."""
        parts = repo_full_name.strip("/").split("/")
        if len(parts) >= 2:
            return parts[-2], parts[-1]
        return None, None

    def _extract_file_path(self, task: str) -> str:
        """Heuristically extract a file path from a task description."""
        # Look for explicit file path mentions
        patterns = [
            r"(?:file|edit|update|create|modify|add to|write to)\s+[`'\"]?([^\s`'\"]+\.\w+)[`'\"]?",
            r"([^\s]+\.(?:py|js|ts|dart|md|txt|json|yaml|yml|sh|html|css))",
        ]
        for p in patterns:
            m = re.search(p, task, re.IGNORECASE)
            if m:
                return m.group(1)
        # Default fallback
        return "CHANGES.md"

    # ──────────────────────────────────────────────
    # PUBLIC API
    # ──────────────────────────────────────────────

    async def edit_file(
        self, repo_full_name: str, file_path: str, task: str, commit_message: str = ""
    ) -> dict:
        """
        Read a file, use Gemini to generate new content, then commit back.
        Returns: {success, commit_sha, file_url, file_path, repo}
        """
        if not self.enabled:
            return {"success": False, "error": "No GitHub token available."}

        owner, repo = self._parse_owner_repo(repo_full_name)
        if not owner:
            return {"success": False, "error": "Invalid repo format."}

        default_branch = await self._get_default_branch(owner, repo)
        file_data = await self._get_file(owner, repo, file_path, ref=default_branch)
        if file_data is None:
            return {"success": False, "error": "Could not read file from GitHub."}

        # Generate new content with Gemini
        new_content = await self._ai_generate_content(
            task=task,
            existing_content=file_data["content"],
            file_path=file_path,
        )

        # Commit the change
        msg = commit_message or f"feat: {task[:60]}"
        result = await self._put_file(
            owner=owner,
            repo=repo,
            path=file_path,
            content=new_content,
            message=msg,
            sha=file_data.get("sha"),
            branch=default_branch,
        )
        if result.get("success"):
            result["file_path"] = file_path
            result["repo"] = repo_full_name
        return result

    async def create_file(
        self, repo_full_name: str, file_path: str, content: str, commit_message: str
    ) -> dict:
        """Create a brand-new file in the repository."""
        if not self.enabled:
            return {"success": False, "error": "No GitHub token available."}

        owner, repo = self._parse_owner_repo(repo_full_name)
        if not owner:
            return {"success": False, "error": "Invalid repo format."}

        default_branch = await self._get_default_branch(owner, repo)
        result = await self._put_file(
            owner=owner,
            repo=repo,
            path=file_path,
            content=content,
            message=commit_message,
            sha=None,  # no SHA = create new file
            branch=default_branch,
        )
        if result.get("success"):
            result["file_path"] = file_path
            result["repo"] = repo_full_name
        return result

    async def execute_task_and_pr(
        self, repo_full_name: str, task: str, branch_name: str = None
    ) -> dict:
        """
        Full agentic workflow:
        1. Detect file from task description
        2. AI-generate new content with Gemini
        3. Commit to a new feature branch
        4. Open a Pull Request
        Returns full result with PR URL.
        """
        if not self.enabled:
            return {"success": False, "error": "No GitHub token available."}

        owner, repo = self._parse_owner_repo(repo_full_name)
        if not owner:
            return {"success": False, "error": "Invalid repo format."}

        default_branch = await self._get_default_branch(owner, repo)
        file_path = self._extract_file_path(task)
        feature_branch = branch_name or f"tatvik/agent-task"

        # Step 1: Create feature branch
        await self._create_branch(owner, repo, feature_branch, default_branch)

        # Step 2: Read existing file (may not exist)
        file_data = await self._get_file(owner, repo, file_path, ref=feature_branch)
        existing = file_data["content"] if file_data and file_data["found"] else ""

        # Step 3: Generate content with Gemini
        new_content = await self._ai_generate_content(
            task=task, existing_content=existing, file_path=file_path
        )

        # Step 4: Commit to feature branch
        result = await self._put_file(
            owner=owner,
            repo=repo,
            path=file_path,
            content=new_content,
            message=f"feat: {task[:72]}",
            sha=file_data.get("sha") if file_data and file_data["found"] else None,
            branch=feature_branch,
        )
        if not result.get("success"):
            return result

        # Step 5: Open Pull Request
        pr_result = await self._create_pr(
            owner=owner,
            repo=repo,
            title=f"[Tatvik Agent] {task[:80]}",
            body=(
                f"## 🤖 Tatvik AI Agent Task\n\n"
                f"**Task:** {task}\n\n"
                f"**File modified:** `{file_path}`\n\n"
                f"**Generated by:** Tatvik AI OS (Gemini 2.0 Flash)\n"
            ),
            head=feature_branch,
            base=default_branch,
        )

        return {
            "success": True,
            "file_path": file_path,
            "file_url": result.get("file_url"),
            "commit_sha": result.get("commit_sha"),
            "pull_request_url": pr_result.get("pr_url"),
            "repo": repo_full_name,
            "task": task,
        }

    async def read_file(self, repo_full_name: str, file_path: str) -> dict:
        """Read a file's content from a GitHub repository."""
        if not self.enabled:
            return {"success": False, "error": "No GitHub token available."}
        owner, repo = self._parse_owner_repo(repo_full_name)
        default_branch = await self._get_default_branch(owner, repo)
        data = await self._get_file(owner, repo, file_path, ref=default_branch)
        if data and data["found"]:
            return {"success": True, "content": data["content"], "path": file_path}
        return {"success": False, "error": f"File '{file_path}' not found."}
