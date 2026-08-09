"""
Mission → PR Service
====================
Turns a Tatvik command-center mission into a real, professional pull request.

Flow:
  1. Understand the repository using the Cognee knowledge graph + the live
     GitHub file tree (never edits on the default branch).
  2. Ask the LLM to identify the significant files/changes needed for the
     mission (using the graph-derived context so changes fit the codebase).
  3. Create a feature branch, apply the changes via the GitHub Contents API,
     and open a properly described pull request.

Every step degrades gracefully: when no GitHub token or no AI key is
configured the service reports what it would have done instead of failing.
"""

from __future__ import annotations

import base64
import json
import logging
import re
import time
from datetime import datetime, timezone

import httpx

from app.core.config import settings
from app.services.cognee_service import CogneeService

logger = logging.getLogger(__name__)

GITHUB_API = "https://api.github.com"


class MissionPrService:
    """Agentic mission → PR executor backed by the GitHub REST API."""

    def __init__(self, github_token: str):
        self.token = github_token
        self.headers = {
            "Authorization": f"token {github_token}",
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "Tatvik-AI-OS",
        }
        self.enabled = bool(github_token)
        self.cognee = CogneeService()

    # ──────────────────────────────────────────────
    # 1. REPOSITORY UNDERSTANDING (via graph + tree)
    # ──────────────────────────────────────────────

    async def understand_repository(self, repo_full_name: str, user_id: str) -> dict:
        """Build a rich context map of a repository.

        Combines the Cognee knowledge-graph memory (if the repo has been
        indexed / asked about before) with the live GitHub file tree, so the
        mission agent understands architecture and conventions before coding.
        """
        owner, repo = self._parse_owner_repo(repo_full_name)
        if not owner:
            return {
                "success": False,
                "error": f"Invalid repository: {repo_full_name}",
            }

        default_branch = await self._get_default_branch(owner, repo)

        graph_context = ""
        try:
            memory = await self.cognee.query_repository_memory(
                user_id=user_id,
                repo_name=repo_full_name,
                query=(
                    "architecture, tech stack, main modules, key files, "
                    "coding conventions, and recent changes in this repository"
                ),
            )
            if memory:
                graph_context = str(memory)[:3000]
        except Exception as e:
            logger.warning(f"Graph recall failed for {repo_full_name}: {e}")

        tree = await self._get_file_tree(owner, repo, default_branch)
        key_files = await self._sample_key_files(owner, repo, tree, default_branch)

        context = {
            "repo": repo_full_name,
            "default_branch": default_branch,
            "graph_context": graph_context,
            "file_tree": tree[:400],
            "key_files": key_files,
            "languages": self._infer_languages(tree),
            "readme": await self._get_readme(owner, repo, default_branch),
        }

        rendered = self._render_context(context)
        # Persist understanding into the graph for future missions
        try:
            if self.cognee.enabled and (tree or graph_context):
                await self.cognee.index_repository(
                    user_id=user_id,
                    repo_name=repo_full_name,
                    codebase_files=[{"path": "repo_context.md", "content": rendered}],
                )
        except Exception as e:
            logger.warning(f"Graph index failed for {repo_full_name}: {e}")

        context["rendered"] = rendered
        return {"success": True, "context": context}

    async def _get_default_branch(self, owner: str, repo: str) -> str:
        url = f"{GITHUB_API}/repos/{owner}/{repo}"
        async with httpx.AsyncClient() as client:
            try:
                resp = await client.get(url, headers=self.headers, timeout=15.0)
                if resp.status_code == 200:
                    return resp.json().get("default_branch", "master")
            except Exception:
                pass
        return "master"

    async def _get_file_tree(self, owner: str, repo: str, branch: str) -> list[str]:
        """Fetch the recursive git tree of a branch (paths only)."""
        url = f"{GITHUB_API}/repos/{owner}/{repo}/git/trees/{branch}?recursive=1"
        async with httpx.AsyncClient() as client:
            try:
                resp = await client.get(url, headers=self.headers, timeout=30.0)
                if resp.status_code == 200:
                    tree = resp.json().get("tree", [])
                    return [
                        t["path"]
                        for t in tree
                        if t.get("type") == "blob" and t.get("path")
                    ]
            except Exception as e:
                logger.warning(f"Failed to fetch tree for {owner}/{repo}: {e}")
        return []

    async def _sample_key_files(
        self, owner: str, repo: str, tree: list[str], branch: str
    ) -> list[dict]:
        """Read a small sample of the most important files for context."""
        if not tree:
            return []

        priority = [
            "README.md",
            "README.rst",
            "pyproject.toml",
            "setup.py",
            "setup.cfg",
            "package.json",
            "pubspec.yaml",
            "go.mod",
            "Cargo.toml",
            "requirements.txt",
            "pom.xml",
            "build.gradle",
            ".env.example",
            "docker-compose.yml",
            "Makefile",
        ]

        files = []
        for p in priority:
            if p in tree:
                files.append(p)
        # fallback: a couple of top-level source dirs
        if not files:
            for p in tree[:20]:
                if "/" not in p:
                    files.append(p)
        if not files:
            files = tree[:10]

        results = []
        for path in files[:8]:
            content = await self._get_file_content(owner, repo, path, branch)
            if content is not None:
                results.append({"path": path, "content": content[:1500]})
        return results

    async def _get_file_content(
        self, owner: str, repo: str, path: str, ref: str
    ) -> str | None:
        url = f"{GITHUB_API}/repos/{owner}/{repo}/contents/{path}"
        async with httpx.AsyncClient() as client:
            try:
                resp = await client.get(
                    url, headers=self.headers, params={"ref": ref}, timeout=15.0
                )
                if resp.status_code == 200:
                    data = resp.json()
                    return base64.b64decode(data["content"]).decode("utf-8", "replace")
                if resp.status_code == 404:
                    return None
            except Exception:
                pass
        return None

    async def _get_readme(self, owner: str, repo: str, branch: str) -> str:
        for name in ("README.md", "README.rst", "Readme.md", "readme.md"):
            content = await self._get_file_content(owner, repo, name, branch)
            if content:
                return content[:2000]
        return ""

    @staticmethod
    def _infer_languages(tree: list[str]) -> list[str]:
        ext_map = {
            ".py": "Python",
            ".js": "JavaScript",
            ".ts": "TypeScript",
            ".dart": "Dart",
            ".go": "Go",
            ".rs": "Rust",
            ".java": "Java",
            ".cpp": "C++",
            ".rb": "Ruby",
            ".php": "PHP",
            ".swift": "Swift",
            ".kt": "Kotlin",
        }
        langs = set()
        for path in tree:
            for ext, lang in ext_map.items():
                if path.endswith(ext):
                    langs.add(lang)
                    break
        return sorted(langs)

    @staticmethod
    def _render_context(context: dict) -> str:
        parts = [
            f"REPOSITORY: {context.get('repo', '')}",
            f"DEFAULT_BRANCH: {context.get('default_branch', 'master')}",
        ]
        if context.get("languages"):
            parts.append(f"LANGUAGES: {', '.join(context['languages'])}")
        if context.get("graph_context"):
            parts.append(f"GRAPH_MEMORY:\n{context['graph_context'][:2000]}")
        if context.get("readme"):
            parts.append(f"README:\n{context['readme'][:1200]}")
        parts.append("KEY_FILES:")
        for f in context.get("key_files", [])[:5]:
            parts.append(f"\n### {f['path']}\n{f['content'][:800]}")
        if context.get("file_tree"):
            sample = context["file_tree"][:150]
            parts.append(f"FILE_TREE_SAMPLE ({len(context['file_tree'])} files):")
            parts.append("\n".join(f"  - {p}" for p in sample))
        return "\n\n".join(parts)

    # ──────────────────────────────────────────────
    # 2. CHANGE PLANNING + EXECUTION
    # ──────────────────────────────────────────────

    async def execute_mission_and_open_pr(
        self,
        repo_full_name: str,
        mission_title: str,
        mission_description: str,
        user_id: str = "",
        repo_context: str = "",
    ) -> dict:
        """Full flow: understand repo → generate changes → open PR."""
        if not self.enabled:
            return {
                "success": False,
                "error": "No GitHub token available. Connect GitHub to open PRs.",
                "message": "Mission completed in dry-run: no PR created.",
            }

        owner, repo = self._parse_owner_repo(repo_full_name)
        if not owner:
            return {"success": False, "error": f"Invalid repository: {repo_full_name}"}

        # 1. Understand the repository (graph + live tree)
        if not repo_context:
            understood = await self.understand_repository(repo_full_name, user_id)
            if not understood.get("success"):
                return understood
            repo_context = understood["context"]["rendered"]

        context_map = {
            "repo": repo_full_name,
            "context": repo_context,
        }

        # 2. Ask the LLM for a concrete change plan (files + diffs)
        plan = await self._plan_changes(
            mission_title=mission_title,
            mission_description=mission_description,
            repo_context=repo_context,
        )

        if not plan.get("changes"):
            # Nothing significant to change — report and stop.
            return {
                "success": True,
                "no_changes_needed": True,
                "message": plan.get("reasoning", "No significant changes needed."),
                "repo": repo_full_name,
            }

        # 3. Create a feature branch and apply the changes
        default_branch = await self._get_default_branch(owner, repo)
        branch = self._branch_name(mission_title)
        created = await self._create_branch(owner, repo, branch, default_branch)
        if not created:
            # Branch may already exist from a previous attempt — reuse it.
            logger.info(f"Branch {branch} exists or failed; attempting reuse.")

        committed = []
        for change in plan["changes"]:
            path = self._safe_path(change.get("path", ""))
            if not path:
                continue
            content = change.get("content")
            if content is None:
                content = self._stub_change(path, mission_title)
            result = await self._put_file(
                owner=owner,
                repo=repo,
                path=path,
                content=content,
                message=f"{plan.get('commit_prefix', 'feat')}: {mission_title[:60]}",
                branch=branch,
            )
            if result.get("success"):
                committed.append({"path": path, "file_url": result.get("file_url")})

        if not committed:
            return {
                "success": False,
                "error": "No files could be written to the branch.",
                "repo": repo_full_name,
            }

        # 4. Open the pull request with a proper description
        pr_title = self._pr_title(mission_title)
        pr_body = self._pr_body(
            mission_title=mission_title,
            mission_description=mission_description,
            changes=[c["path"] for c in committed],
            reasoning=plan.get("reasoning", ""),
            repo_context=repo_context,
        )
        pr = await self._create_pr(
            owner=owner,
            repo=repo,
            title=pr_title,
            body=pr_body,
            head=branch,
            base=default_branch,
        )

        return {
            "success": pr.get("success", False),
            "pull_request_url": pr.get("pr_url"),
            "branch_name": branch,
            "files_changed": [c["path"] for c in committed],
            "changes_count": len(committed),
            "repo": repo_full_name,
            "pr_error": pr.get("error"),
        }

    # ── LLM planning ──────────────────────────────

    async def _plan_changes(
        self,
        mission_title: str,
        mission_description: str,
        repo_context: str,
    ) -> dict:
        """Ask the LLM what significant changes the mission needs."""
        prompt = (
            "You are the Tatvik AI OS coding agent. Based ONLY on the repository "
            "context below, decide the significant code changes required to "
            "complete the mission.\n\n"
            f"MISSION TITLE: {mission_title}\n"
            f"MISSION DESCRIPTION: {mission_description}\n\n"
            f"REPOSITORY CONTEXT:\n{repo_context[:6000]}\n\n"
            "Return STRICT JSON with this exact shape:\n"
            "{\n"
            '  "reasoning": "one paragraph explaining what must change and why",\n'
            '  "commit_prefix": "feat | fix | chore | docs | refactor",\n'
            '  "changes": [\n'
            "    {\n"
            '      "path": "full/path/to/file",\n'
            '      "content": "complete new file content (or complete replacement of the existing file)"\n'
            "    }\n"
            "  ]\n"
            "}\n"
            "- changes MUST be a real path from the repo file tree if modifying "
            "an existing file; you may create a new file only when clearly required.\n"
            '- If the mission needs NO code change, return {"reasoning": "...", "changes": []}.\n'
            "- Return raw JSON only — no markdown fences, no commentary."
        )

        text = await self._generate_text(prompt)
        return self._parse_plan(text)

    async def _generate_text(self, prompt: str) -> str:
        """Generate text via OpenClaw gateway, then Gemini, then NVIDIA."""
        from app.services.openclaw_service import OpenClawService

        openclaw = OpenClawService()
        try:
            if openclaw.enabled:
                result = await openclaw.generate(prompt, timeout=180.0)
                if result.get("success"):
                    return str(result.get("output", ""))
        except Exception as e:
            logger.warning(f"OpenClaw plan generation failed: {e}")

        if settings.gemini_api_key:
            try:
                from app.api.v1.endpoints.research import call_gemini

                text = await call_gemini(
                    "You are a precise coding agent that returns only JSON.",
                    prompt,
                )
                if text and not text.startswith("Error"):
                    return text
            except Exception as e:
                logger.warning(f"Gemini plan generation failed: {e}")

        if settings.nvidia_api_key:
            try:
                url = "https://integrate.api.nvidia.com/v1/chat/completions"
                async with httpx.AsyncClient() as client:
                    resp = await client.post(
                        url,
                        json={
                            "model": "meta/llama-3.3-70b-instruct",
                            "messages": [{"role": "user", "content": prompt}],
                        },
                        headers={
                            "Authorization": f"Bearer {settings.nvidia_api_key}",
                            "Content-Type": "application/json",
                        },
                        timeout=60.0,
                    )
                    if resp.status_code == 200:
                        return resp.json()["choices"][0]["message"]["content"].strip()
            except Exception as e:
                logger.warning(f"NVIDIA plan generation failed: {e}")

        logger.warning("No AI provider available for mission planning.")
        return ""

    @staticmethod
    def _parse_plan(text: str) -> dict:
        if not text:
            return {"reasoning": "", "changes": []}
        # Strip markdown fences if present
        cleaned = re.sub(r"```(?:json)?", "", text).strip()
        try:
            start = cleaned.find("{")
            end = cleaned.rfind("}")
            if start >= 0 and end > start:
                data = json.loads(cleaned[start : end + 1])
            else:
                data = json.loads(cleaned)
        except Exception:
            # Last resort: naive list-of-objects extraction
            data = {}
            match = re.search(r"\[\s*\{.*\}\s*\]", cleaned, re.DOTALL)
            if match:
                try:
                    changes = json.loads(match.group(0))
                    return {"reasoning": "", "changes": changes}
                except Exception:
                    pass
            return {"reasoning": "", "changes": []}

        changes = data.get("changes", [])
        if isinstance(changes, list):
            safe = []
            for c in changes:
                if isinstance(c, dict) and c.get("path"):
                    safe.append(
                        {
                            "path": c["path"],
                            "content": str(c.get("content", "")),
                        }
                    )
            data["changes"] = safe
        return data

    # ── GitHub file/branch/PR helpers ─────────────

    async def _put_file(
        self,
        owner: str,
        repo: str,
        path: str,
        content: str,
        message: str,
        branch: str,
    ):
        url = f"{GITHUB_API}/repos/{owner}/{repo}/contents/{path}"
        encoded = base64.b64encode(content.encode("utf-8")).decode("utf-8")
        payload = {"message": message, "content": encoded, "branch": branch}

        # Fetch existing SHA for updates
        existing = await self._get_file_sha(owner, repo, path, branch)
        if existing:
            payload["sha"] = existing

        async with httpx.AsyncClient() as client:
            try:
                resp = await client.put(
                    url, headers=self.headers, json=payload, timeout=20.0
                )
                if resp.status_code in (200, 201):
                    data = resp.json()
                    return {
                        "success": True,
                        "commit_sha": data.get("commit", {}).get("sha"),
                        "file_url": data.get("content", {}).get("html_url", ""),
                    }
                logger.error(f"GitHub put file {resp.status_code}: {resp.text[:300]}")
            except Exception as e:
                logger.warning(f"GitHub put file failed: {e}")
        return {"success": False, "error": "Failed to write file."}

    async def _get_file_sha(
        self, owner: str, repo: str, path: str, ref: str
    ) -> str | None:
        url = f"{GITHUB_API}/repos/{owner}/{repo}/contents/{path}"
        async with httpx.AsyncClient() as client:
            try:
                resp = await client.get(
                    url, headers=self.headers, params={"ref": ref}, timeout=15.0
                )
                if resp.status_code == 200:
                    return resp.json().get("sha")
            except Exception:
                pass
        return None

    async def _create_branch(
        self, owner: str, repo: str, branch: str, from_branch: str
    ) -> bool:
        ref_url = f"{GITHUB_API}/repos/{owner}/{repo}/git/refs/heads/{from_branch}"
        async with httpx.AsyncClient() as client:
            try:
                ref_resp = await client.get(ref_url, headers=self.headers, timeout=15.0)
                if ref_resp.status_code != 200:
                    return False
                sha = ref_resp.json()["object"]["sha"]

                create_url = f"{GITHUB_API}/repos/{owner}/{repo}/git/refs"
                create_resp = await client.post(
                    create_url,
                    headers=self.headers,
                    json={"ref": f"refs/heads/{branch}", "sha": sha},
                    timeout=15.0,
                )
                return create_resp.status_code in (200, 201)
            except Exception:
                return False

    async def _create_pr(
        self, owner: str, repo: str, title: str, body: str, head: str, base: str
    ) -> dict:
        url = f"{GITHUB_API}/repos/{owner}/{repo}/pulls"
        async with httpx.AsyncClient() as client:
            try:
                resp = await client.post(
                    url,
                    headers=self.headers,
                    json={"title": title, "body": body, "head": head, "base": base},
                    timeout=20.0,
                )
                if resp.status_code == 201:
                    return {"success": True, "pr_url": resp.json()["html_url"]}
                logger.error(f"GitHub PR error {resp.status_code}: {resp.text[:300]}")
            except Exception as e:
                logger.warning(f"GitHub PR create failed: {e}")
        return {"success": False, "error": "Failed to create pull request."}

    # ── misc ──────────────────────────────────────

    @staticmethod
    def _parse_owner_repo(repo_full_name: str):
        parts = repo_full_name.strip("/").replace("https://github.com/", "").split("/")
        if len(parts) >= 2:
            return parts[0], parts[1]
        return None, None

    @staticmethod
    def _safe_path(path: str) -> str:
        return re.sub(r"\.\./", "", path).lstrip("/").strip()

    @staticmethod
    def _branch_name(title: str) -> str:
        slug = re.sub(r"[^a-zA-Z0-9]+", "-", title).strip("-").lower()
        if not slug:
            return "tatvik/mission"
        return f"tatvik/mission-{slug[:40]}"

    @staticmethod
    def _pr_title(title: str) -> str:
        return f"🚀 {title} — Tatvik AI OS"

    @staticmethod
    def _stub_change(path: str, title: str) -> str:
        return (
            f"# {title}\n"
            f"# Generated by Tatvik AI OS\n"
            f"# This file was created as part of the mission.\n"
        )

    @staticmethod
    def _pr_body(
        mission_title: str,
        mission_description: str,
        changes: list[str],
        reasoning: str,
        repo_context: str,
    ) -> str:
        now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
        files = "\n".join(f"- `{f}`" for f in changes) or "- _(none)_"
        ctx_preview = repo_context[:1500] if repo_context else "_no context_"
        return (
            f"## Overview\n\n"
            f"This pull request was **Generated autonomously by Tatvik AI OS** "
            f'from the command-center mission **"{mission_title}"**.\n\n'
            f"**Mission description:** {mission_description or 'Not provided.'}\n\n"
            f"## Changes\n\n"
            f"{files}\n\n"
            f"## Reasoning\n\n"
            f"{reasoning or 'Generated from the mission analysis.'}\n\n"
            f"## Repository context used\n\n"
            f"```\n{ctx_preview}\n```\n\n"
            f"---\n\n"
            f"_Generated by Tatvik AI OS — {now}_"
        )
