import httpx
import logging
import tempfile
import os
from datetime import datetime
from app.core.config import settings

logger = logging.getLogger(__name__)


class CogneeService:
    def __init__(self):
        """
        Initializes Cognee Cloud connection and configures target LLM/Vector store credentials.
        """
        self.api_key = settings.cognee_api_key
        self.base_url = settings.cognee_base_url.rstrip("/")

        self.headers = {"Content-Type": "application/json"}
        if self.api_key:
            self.headers["X-Api-Key"] = self.api_key

        self.enabled = bool(self.api_key)
        if not self.enabled:
            logger.warning(
                "Cognee API Key is not configured. Cognee memory layer will operate in stub/dry-run mode."
            )

    async def _trigger_cognify(self, dataset_name: str) -> bool:
        """
        Triggers the Cognee cognify pipeline to process raw ingested data
        into a structured knowledge graph for recall.
        """
        url = f"{self.base_url}/api/v1/cognify"
        payload = {
            "datasets": [dataset_name],
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=120.0
                )
                if response.status_code == 200:
                    logger.info(
                        f"Cognify triggered successfully for dataset: {dataset_name}"
                    )
                    return True
                logger.warning(
                    f"Cognify returned {response.status_code}: {response.text}"
                )
                return False
            except Exception as e:
                logger.warning(f"Cognify trigger failed (non-critical): {e}")
                return False

    async def add_developer_profile(self, user_id: str, profile_data: dict) -> bool:
        """
        Saves user developer strengths, weaknesses, mistakes, and project history into the long-term memory graph.
        """
        if not self.enabled:
            logger.info(
                f"[Stub] Added developer profile for user {user_id}: {profile_data}"
            )
            return True

        url = f"{self.base_url}/api/v1/remember/entry"
        dataset_name = f"user_{user_id}"
        payload = {
            "entry": {
                "type": "qa",
                "question": f"What is the developer profile, strengths, and weaknesses for user {user_id}?",
                "answer": str(profile_data),
            },
            "dataset_name": dataset_name,
            "session_id": f"devmentor_{user_id}",
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=30.0
                )
                if response.status_code == 200:
                    # Trigger cognify to process into the knowledge graph
                    await self._trigger_cognify(dataset_name)
                    return True
                logger.error(f"Failed to add developer profile: {response.text}")
                return False
            except Exception as e:
                logger.exception(f"Failed to communicate with Cognee Cloud: {e}")
                return False

    async def get_developer_profile(self, user_id: str) -> dict:
        """
        Retrieves the long-term developer profile and mistake list from the memory layer.
        """
        if not self.enabled:
            logger.info(f"[Stub] Get developer profile for user {user_id}")
            return {
                "message": "Cognee API key not set. Using local database profile instead."
            }

        url = f"{self.base_url}/api/v1/recall"
        payload = {
            "query": f"developer profile metadata weaknesses strengths mistakes user_{user_id}",
            "session_id": f"devmentor_{user_id}",
            "search_type": "GRAPH_COMPLETION",
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=60.0
                )
                if response.status_code == 200:
                    return {"results": response.json()}
                logger.error(f"Failed to recall developer profile: {response.text}")
                return {"error": response.text}
            except Exception as e:
                logger.exception(f"Failed to query Cognee Cloud profile: {e}")
                return {"error": str(e)}

    async def index_repository(
        self, user_id: str, repo_name: str, codebase_files: list[dict]
    ) -> bool:
        """
        Ingests codebase metadata, architecture files (prompts.md, logs.md, todos.md), and directory maps.
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

        # We must use file upload for raw knowledge ingestion, NO session_id
        url = f"{self.base_url}/api/v1/remember"
        headers = {"X-Api-Key": self.api_key}  # no application/json

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
                    data = {"datasetName": f"user_{user_id}"}
                    response = await client.post(
                        url, headers=headers, files=files, data=data, timeout=300.0
                    )

            os.remove(tmp_path)

            if response.status_code == 200:
                # Trigger cognify to build the knowledge graph
                await self._trigger_cognify(f"user_{user_id}")
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
        Performs vector-graph search over the repo memory to explain code patterns or search architecture.
        """
        if not self.enabled:
            logger.info(
                f"[Stub] Querying repository {repo_name} for user {user_id}: {query}"
            )
            return []

        url = f"{self.base_url}/api/v1/recall"
        payload = {
            "query": f"For repository {repo_name}: {query}",
            "session_id": f"devmentor_{user_id}",
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
        Persists a code review result (scores + issues) into Cognee so the AI
        can recall past mistakes and track improvement over time.
        """
        if not self.enabled:
            return True

        url = f"{self.base_url}/api/v1/remember/entry"
        dataset_name = f"user_{user_id}"
        payload = {
            "entry": {
                "type": "qa",
                "question": (
                    f"What were the code review results for {repo_name} "
                    f"reviewed on {datetime.utcnow().isoformat()}?"
                ),
                "answer": str(review_data),
            },
            "dataset_name": dataset_name,
            "session_id": f"devmentor_{user_id}",
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=30.0
                )
                if response.status_code == 200:
                    await self._trigger_cognify(dataset_name)
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
        Records a specific coding mistake into the user's long-term memory
        so the mentor can warn them about recurring patterns.
        """
        if not self.enabled:
            return True

        url = f"{self.base_url}/api/v1/remember/entry"
        dataset_name = f"user_{user_id}"
        payload = {
            "entry": {
                "type": "qa",
                "question": (
                    f"What coding mistake did user {user_id} make in "
                    f"the category '{category}'?"
                ),
                "answer": mistake_description,
            },
            "dataset_name": dataset_name,
            "session_id": f"devmentor_{user_id}",
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=30.0
                )
                if response.status_code == 200:
                    await self._trigger_cognify(dataset_name)
                    return True
                return False
            except Exception as e:
                logger.warning(f"Failed to store mistake: {e}")
                return False

    async def get_weekly_growth_data(self, user_id: str) -> dict:
        """
        Recalls all review results, mistakes, and improvements from the
        past week to generate a growth report.
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
            "session_id": f"devmentor_{user_id}",
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
        Natural language Q&A over an indexed codebase. Users can ask things
        like 'Where is authentication handled?' or 'What database does this use?'
        """
        if not self.enabled:
            return "Cognee is not configured. Cannot search codebase."

        url = f"{self.base_url}/api/v1/recall"
        payload = {
            "query": question,
            "session_id": f"devmentor_{user_id}",
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
                return f"Search failed: {e}"

    async def get_skill_badges(self, user_id: str) -> dict:
        """
        Queries all historical review data and determines which skill badges
        the developer has earned based on consistent performance.
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
            "session_id": f"devmentor_{user_id}",
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
