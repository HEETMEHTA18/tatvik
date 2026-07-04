import httpx
import logging
import tempfile
import os
from datetime import datetime, timezone
from app.core.config import settings

logger = logging.getLogger(__name__)


class CogneeService:
    """
    Cognee Memory Layer — stores and retrieves data inside a named brain
    with topic-based sessions for structured recall.
    """

    def __init__(self):
        """
        Initializes Cognee Cloud connection and configures target LLM/Vector store credentials.
        """
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

    # ── Brain / Dataset helpers ───────────────────────────────────────────────

    @property
    def _brain(self) -> str:
        """The brain (dataset) all data is stored under."""
        return self.brain_name

    def _session(self, topic: str) -> str:
        """Topic-based session ID within the Tatvik brain."""
        return f"tatvik_{topic}"

    async def _trigger_cognify(self) -> bool:
        """
        Triggers the Cognee cognify pipeline to process raw ingested data
        into a structured knowledge graph for recall within the Tatvik brain.
        """
        url = f"{self.base_url}/api/v1/cognify"
        payload = {"datasets": [self._brain]}

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=120.0
                )
                if response.status_code == 200:
                    logger.info(
                        f"Cognify triggered successfully for brain: {self._brain}"
                    )
                    return True
                logger.warning(
                    f"Cognify returned {response.status_code}: {response.text}"
                )
                return False
            except Exception as e:
                logger.warning(f"Cognify trigger failed (non-critical): {e}")
                return False

    # ── Developer Profile ─────────────────────────────────────────────────────

    async def add_developer_profile(self, user_id: str, profile_data: dict) -> bool:
        """
        Saves user developer strengths, weaknesses, mistakes, and project history
        into the Tatvik brain under the 'profile' session.
        """
        if not self.enabled:
            logger.info(
                f"[Stub] Added developer profile for user {user_id}: {profile_data}"
            )
            return True

        url = f"{self.base_url}/api/v1/remember/entry"
        payload = {
            "entry": {
                "type": "qa",
                "question": f"What is the developer profile, strengths, and weaknesses for user {user_id}?",
                "answer": str(profile_data),
            },
            "dataset_name": self._brain,
            "session_id": self._session("profile"),
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=30.0
                )
                if response.status_code == 200:
                    await self._trigger_cognify()
                    return True
                logger.error(f"Failed to add developer profile: {response.text}")
                return False
            except Exception as e:
                logger.exception(f"Failed to communicate with Cognee Cloud: {e}")
                return False

    async def get_developer_profile(self, user_id: str) -> dict:
        """
        Retrieves the long-term developer profile from the 'profile' session
        within the Tatvik brain.
        """
        if not self.enabled:
            logger.info(f"[Stub] Get developer profile for user {user_id}")
            return {
                "message": "Cognee API key not set. Using local database profile instead."
            }

        url = f"{self.base_url}/api/v1/recall"
        payload = {
            "query": f"developer profile metadata weaknesses strengths mistakes user_{user_id}",
            "session_id": self._session("profile"),
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
                    f"Failed to recall developer profile (status {response.status_code})"
                )
                return {"results": [], "success": False}
            except Exception as e:
                logger.exception("Failed to query Cognee Cloud profile")
                return {"results": [], "success": False}

    # ── Repository Indexing ───────────────────────────────────────────────────

    async def index_repository(
        self, user_id: str, repo_name: str, codebase_files: list[dict]
    ) -> bool:
        """
        Ingests codebase metadata into the Tatvik brain under the 'repo_index' session.
        """
        if not self.enabled:
            logger.info(
                f"[Stub] Indexing repository {repo_name} with {len(codebase_files)} files for user {user_id}"
            )
            return True

        texts = [
            f"File {file.get('path')}: {file.get('content', '')}"
            for file in codebase_files
        ]
        combined = "\n\n".join(texts)

        url = f"{self.base_url}/api/v1/remember"
        headers = {"X-Api-Key": self.api_key}

        try:
            with tempfile.NamedTemporaryFile(
                mode="w+", delete=False, suffix=".txt"
            ) as tmp:
                tmp.write(combined)
                tmp_path = tmp.name

            async with httpx.AsyncClient() as client:
                with open(tmp_path, "rb") as f:
                    files = {
                        "data": (f"{repo_name.replace('/', '_')}.txt", f, "text/plain")
                    }
                    data = {"datasetName": self._brain}
                    response = await client.post(
                        url, headers=headers, files=files, data=data, timeout=300.0
                    )

            os.remove(tmp_path)

            if response.status_code == 200:
                await self._trigger_cognify()
                return True
            logger.error(f"Failed to index repository in Cognee Cloud: {response.text}")
            return False
        except Exception as e:
            logger.exception(f"Failed to index repository to Cognee Cloud: {e}")
            return False

    async def query_repository_memory(
        self, user_id: str, repo_name: str, query: str
    ) -> list:
        """
        Queries the 'repo_index' session within the Tatvik brain.
        """
        if not self.enabled:
            logger.info(
                f"[Stub] Querying repository {repo_name} for user {user_id}: {query}"
            )
            return []

        url = f"{self.base_url}/api/v1/recall"
        payload = {
            "query": f"For repository {repo_name}: {query}",
            "session_id": self._session("repo_index"),
            "search_type": "HYBRID_COMPLETION",
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=60.0
                )
                if response.status_code == 200:
                    return response.json()
                logger.error(f"Failed to query repository memory: {response.text}")
                return []
            except Exception as e:
                logger.exception(f"Failed to query Cognee Cloud repo memory: {e}")
                return []

    # ──────────────────────────────────────────────
    # MISTAKE MEMORY & REVIEW HISTORY
    # ──────────────────────────────────────────────

    async def remember_review_result(
        self, user_id: str, repo_name: str, review_data: dict
    ) -> bool:
        """
        Persists a code review result into the 'review' session within the Tatvik brain.
        """
        if not self.enabled:
            return True

        url = f"{self.base_url}/api/v1/remember/entry"
        payload = {
            "entry": {
                "type": "qa",
                "question": (
                    f"What were the code review results for {repo_name} "
                    f"reviewed on {datetime.now(timezone.utc).isoformat()}?"
                ),
                "answer": str(review_data),
            },
            "dataset_name": self._brain,
            "session_id": self._session("review"),
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=30.0
                )
                if response.status_code == 200:
                    await self._trigger_cognify()
                    return True
                logger.error(f"Failed to remember review result: {response.text}")
                return False
            except Exception as e:
                logger.exception(f"Failed to store review in Cognee: {e}")
                return False

    async def remember_mistake(
        self, user_id: str, mistake_description: str, category: str
    ) -> bool:
        """
        Records a specific coding mistake into the 'mistake' session within the Tatvik brain.
        """
        if not self.enabled:
            return True

        url = f"{self.base_url}/api/v1/remember/entry"
        payload = {
            "entry": {
                "type": "qa",
                "question": (
                    f"What coding mistake did user {user_id} make in "
                    f"the category '{category}'?"
                ),
                "answer": mistake_description,
            },
            "dataset_name": self._brain,
            "session_id": self._session("mistake"),
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=30.0
                )
                if response.status_code == 200:
                    await self._trigger_cognify()
                    return True
                return False
            except Exception as e:
                logger.warning(f"Failed to store mistake: {e}")
                return False

    async def get_weekly_growth_data(self, user_id: str) -> dict:
        """
        Recalls growth data from the 'growth' session within the Tatvik brain.
        """
        if not self.enabled:
            return {"results": []}

        url = f"{self.base_url}/api/v1/recall"
        payload = {
            "query": (
                f"Summarize all code review scores, mistakes, improvements, "
                f"and skill progress for user {user_id} from the past week. "
                f"Include security, performance, architecture, and "
                f"maintainability trends."
            ),
            "session_id": self._session("growth"),
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
                logger.warning(f"Failed to get weekly growth data: {e}")
                return {"results": []}

    async def ask_codebase(self, user_id: str, question: str) -> str:
        """
        Natural language Q&A over indexed codebases from the 'codebase_qa' session.
        """
        if not self.enabled:
            return "Cognee is not configured. Cannot search codebase."

        url = f"{self.base_url}/api/v1/recall"
        payload = {
            "query": question,
            "session_id": self._session("codebase_qa"),
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
        """
        Queries skill badge data from the 'badges' session within the Tatvik brain.
        """
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
            "session_id": self._session("badges"),
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
                logger.warning(f"Failed to get badge data: {e}")
                return {"results": []}
