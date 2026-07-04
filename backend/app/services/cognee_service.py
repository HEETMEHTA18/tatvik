import httpx
import logging
import tempfile
import os
from datetime import datetime, timezone
from app.core.config import settings

logger = logging.getLogger(__name__)


class CogneeService:
    """
    Cognee Memory Layer — stores data in the permanent knowledge graph
    under the "Tatvik brain" dataset. Data is uploaded as text files
    (without session_id) so it goes through add + cognify and appears
    in the Cognee UI knowledge graph immediately.
    """

    def __init__(self):
        self.api_key = settings.cognee_api_key
        self.base_url = settings.cognee_base_url.rstrip("/")
        self.brain_name = settings.cognee_brain_name

        self.headers = {"Content-Type": "application/json"}
        if self.api_key:
            self.headers["X-Api-Key"] = self.api_key

        self.enabled = bool(self.api_key)
        if not self.enabled:
            logger.warning(
                "Cognee API Key is not configured. Cognee memory layer will operate in stub/dry-run mode."
            )

    # ── Helpers ────────────────────────────────────────────────────────────────

    async def _store_text(self, topic: str, content: str) -> bool:
        """
        Upload text as a file to /api/v1/remember WITHOUT session_id.
        This triggers add + cognify, storing data in the permanent knowledge
        graph under the Tatvik brain dataset — visible in the Cognee UI.
        """
        url = f"{self.base_url}/api/v1/remember"
        headers = {"X-Api-Key": self.api_key}

        try:
            with tempfile.NamedTemporaryFile(
                mode="w+", delete=False, suffix=".txt"
            ) as tmp:
                tmp.write(content)
                tmp_path = tmp.name

            async with httpx.AsyncClient() as client:
                with open(tmp_path, "rb") as f:
                    files = {"data": (f"{topic}.txt", f, "text/plain")}
                    data = {"datasetName": self.brain_name}
                    response = await client.post(
                        url, headers=headers, files=files, data=data, timeout=300.0
                    )

            os.remove(tmp_path)

            if response.status_code == 200:
                logger.info(f"Stored '{topic}' in Cognee brain '{self.brain_name}'")
                await self._trigger_cognify()
                return True
            logger.error(
                f"Failed to store '{topic}': {response.status_code} {response.text}"
            )
            return False
        except Exception as e:
            logger.exception(f"Failed to store '{topic}' in Cognee: {e}")
            return False

    async def _trigger_cognify(self) -> bool:
        """Triggers cognify to build the knowledge graph from ingested data."""
        url = f"{self.base_url}/api/v1/cognify"
        payload = {"datasets": [self.brain_name]}

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=120.0
                )
                if response.status_code == 200:
                    logger.info(f"Cognify triggered for brain: {self.brain_name}")
                    return True
                logger.warning(
                    f"Cognify returned {response.status_code}: {response.text}"
                )
                return False
            except Exception as e:
                logger.warning(f"Cognify trigger failed: {e}")
                return False

    # ── Developer Profile ─────────────────────────────────────────────────────

    async def add_developer_profile(self, user_id: str, profile_data: dict) -> bool:
        if not self.enabled:
            logger.info(
                f"[Stub] Added developer profile for user {user_id}: {profile_data}"
            )
            return True

        content = f"TOPIC: profile\n" f"USER: {user_id}\n" f"DATA: {profile_data}\n"
        return await self._store_text(f"profile_{user_id}", content)

    async def get_developer_profile(self, user_id: str) -> dict:
        if not self.enabled:
            return {
                "message": "Cognee API key not set. Using local database profile instead."
            }

        url = f"{self.base_url}/api/v1/recall"
        payload = {
            "query": f"developer profile metadata weaknesses strengths mistakes user_{user_id}",
            "search_type": "GRAPH_COMPLETION",
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=60.0
                )
                if response.status_code == 200:
                    return {"results": response.json()}
                logger.error(
                    f"Failed to recall profile (status {response.status_code})"
                )
                return {"results": [], "success": False}
            except Exception as e:
                logger.exception("Failed to query Cognee profile")
                return {"results": [], "success": False}

    # ── Repository Indexing ───────────────────────────────────────────────────

    async def index_repository(
        self, user_id: str, repo_name: str, codebase_files: list[dict]
    ) -> bool:
        if not self.enabled:
            logger.info(f"[Stub] Indexing {repo_name} with {len(codebase_files)} files")
            return True

        texts = [
            f"File {file.get('path')}: {file.get('content', '')}"
            for file in codebase_files
        ]
        combined = (
            f"TOPIC: repo_index\n"
            f"USER: {user_id}\n"
            f"REPO: {repo_name}\n\n" + "\n\n".join(texts)
        )
        return await self._store_text(f"repo_{repo_name.replace('/', '_')}", combined)

    async def query_repository_memory(
        self, user_id: str, repo_name: str, query: str
    ) -> list:
        if not self.enabled:
            return []

        url = f"{self.base_url}/api/v1/recall"
        payload = {
            "query": f"For repository {repo_name}: {query}",
            "search_type": "HYBRID_COMPLETION",
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=60.0
                )
                if response.status_code == 200:
                    return response.json()
                logger.error(f"Failed to query repo memory: {response.text}")
                return []
            except Exception as e:
                logger.exception(f"Failed to query repo memory: {e}")
                return []

    # ── Review History & Mistakes ──────────────────────────────────────────────

    async def remember_review_result(
        self, user_id: str, repo_name: str, review_data: dict
    ) -> bool:
        if not self.enabled:
            return True

        content = (
            f"TOPIC: review\n"
            f"USER: {user_id}\n"
            f"REPO: {repo_name}\n"
            f"TIMESTAMP: {datetime.now(timezone.utc).isoformat()}\n"
            f"DATA: {review_data}\n"
        )
        return await self._store_text(f"review_{repo_name.replace('/', '_')}", content)

    async def remember_mistake(
        self, user_id: str, mistake_description: str, category: str
    ) -> bool:
        if not self.enabled:
            return True

        content = (
            f"TOPIC: mistake\n"
            f"USER: {user_id}\n"
            f"CATEGORY: {category}\n"
            f"DATA: {mistake_description}\n"
        )
        return await self._store_text(f"mistake_{category}_{user_id}", content)

    async def get_weekly_growth_data(self, user_id: str) -> dict:
        if not self.enabled:
            return {"results": []}

        url = f"{self.base_url}/api/v1/recall"
        payload = {
            "query": (
                f"Summarize all code review scores, mistakes, improvements, "
                f"and skill progress for user {user_id} from the past week. "
                f"Include security, performance, architecture, and maintainability trends."
            ),
            "search_type": "GRAPH_COMPLETION",
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=60.0
                )
                if response.status_code == 200:
                    return {"results": response.json()}
                return {"results": []}
            except Exception as e:
                logger.warning(f"Failed to get weekly growth: {e}")
                return {"results": []}

    async def ask_codebase(self, user_id: str, question: str) -> str:
        if not self.enabled:
            return "Cognee is not configured. Cannot search codebase."

        url = f"{self.base_url}/api/v1/recall"
        payload = {
            "query": question,
            "search_type": "HYBRID_COMPLETION",
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=60.0
                )
                if response.status_code == 200:
                    data = response.json()
                    if isinstance(data, list) and len(data) > 0:
                        return str(data[0])
                    return str(data)
                return "No results found for your question."
            except Exception as e:
                logger.warning(f"Codebase Q&A failed: {e}")
                return "Search failed due to an internal error."

    async def get_skill_badges(self, user_id: str) -> dict:
        if not self.enabled:
            return {"results": []}

        url = f"{self.base_url}/api/v1/recall"
        payload = {
            "query": (
                f"List all code review scores for user {user_id}. "
                f"Include security_score, performance_score, "
                f"architecture_score, and maintainability_score from every "
                f"review session. Return the raw data."
            ),
            "search_type": "GRAPH_COMPLETION",
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=60.0
                )
                if response.status_code == 200:
                    return {"results": response.json()}
                return {"results": []}
            except Exception as e:
                logger.warning(f"Failed to get badges: {e}")
                return {"results": []}
