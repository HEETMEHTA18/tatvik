import httpx
import logging
import tempfile
import os
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
        payload = {
            "entry": {
                "type": "qa",
                "question": f"What is the developer profile, strengths, and weaknesses for user {user_id}?",
                "answer": str(profile_data),
            },
            "dataset_name": f"user_{user_id}",
            "session_id": f"devmentor_{user_id}",
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url, json=payload, headers=self.headers, timeout=30.0
                )
                if response.status_code == 200:
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
