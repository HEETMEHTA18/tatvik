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
    under the "Tatvik brain" dataset.

    Uses the official Cognee Cloud API (X-Api-Key auth):
      * POST /api/v1/remember   — ingest files + build the graph in one call
      * POST /api/v1/recall     — search the graph (graph/session results)
      * POST /api/v1/cognify    — (optional) re-process a dataset explicitly
      * GET  /health            — tenant reachability
      * GET  /api/v1/datasets/  — auth + dataset listing check

    NOTE: /api/v1/remember already performs add + cognify. Calling cognify
    afterwards is redundant and re-processes the dataset, so the service does
    NOT auto-trigger cognify after storing.
    """

    _STORE_TIMEOUT = 300.0
    _RECALL_TIMEOUT = 60.0

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

    @staticmethod
    def _parse_recall_results(data) -> list[str]:
        """Normalize the /api/v1/recall response into a list of text strings.

        Recall returns an array of entries whose shape depends on `source`:
          * graph           -> entry["text"]
          * session (QA)    -> entry["answer"] / entry["context"]
          * session_context -> entry["content"]
          * trace           -> entry["memory_context"]
        """
        if not data:
            return []
        if not isinstance(data, list):
            data = [data]

        results = []
        for entry in data:
            if not isinstance(entry, dict):
                text = str(entry)
            else:
                text = (
                    entry.get("text")
                    or entry.get("answer")
                    or entry.get("content")
                    or entry.get("context")
                    or entry.get("memory_context")
                    or ""
                )
                if not text and entry.get("raw"):
                    raw = entry["raw"]
                    if isinstance(raw, dict):
                        text = (
                            raw.get("text")
                            or raw.get("answer")
                            or raw.get("content")
                            or ""
                        )
            text = str(text or "").strip()
            if text:
                results.append(text)
        return results

    async def _recall(
        self,
        query: str,
        search_type: str = "GRAPH_COMPLETION",
        datasets: list[str] | None = None,
        top_k: int = 15,
    ) -> list[str]:
        """POST /api/v1/recall and return normalized text results."""
        if not self.enabled:
            return []

        payload = {
            "query": query,
            "search_type": search_type,
            "top_k": top_k,
        }
        if datasets is None:
            datasets = [self.brain_name]
        payload["datasets"] = datasets

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    f"{self.base_url}/api/v1/recall",
                    json=payload,
                    headers=self.headers,
                    timeout=self._RECALL_TIMEOUT,
                )
                if response.status_code == 200:
                    return self._parse_recall_results(response.json())
                logger.error(
                    f"Recall failed ({response.status_code}): {response.text[:500]}"
                )
                return []
            except Exception as e:
                logger.exception(f"Failed to recall from Cognee: {e}")
                return []

    async def _store_text(
        self, topic: str, content: str, run_in_background: bool = True
    ) -> bool:
        """
        Upload text as a file to /api/v1/remember WITHOUT session_id.
        This triggers add + cognify in one call, storing data in the permanent
        knowledge graph under the Tatvik brain dataset.

        run_in_background=True returns immediately (status 'running') while the
        graph builds server-side — avoids blocking mission/review flows on a
        multi-minute cognify pipeline.
        """
        if not self.enabled:
            logger.info(f"[Stub] Storing '{topic}' in Cognee brain '{self.brain_name}'")
            return True

        url = f"{self.base_url}/api/v1/remember"
        headers = {"X-Api-Key": self.api_key}

        try:
            with tempfile.NamedTemporaryFile(
                mode="w+", delete=False, suffix=".txt"
            ) as tmp:
                tmp.write(content)
                tmp_path = tmp.name

            try:
                async with httpx.AsyncClient() as client:
                    with open(tmp_path, "rb") as f:
                        files = {"data": (f"{topic}.txt", f, "text/plain")}
                        data = {
                            "datasetName": self.brain_name,
                            "run_in_background": str(run_in_background).lower(),
                        }
                        response = await client.post(
                            url,
                            headers=headers,
                            files=files,
                            data=data,
                            timeout=self._STORE_TIMEOUT,
                        )
            finally:
                os.remove(tmp_path)

            if response.status_code == 200:
                logger.info(
                    f"Stored '{topic}' in Cognee brain '{self.brain_name}'"
                    f" (run_in_background={run_in_background})"
                )
                return True
            logger.error(
                f"Failed to store '{topic}': {response.status_code} {response.text[:500]}"
            )
            return False
        except Exception as e:
            logger.exception(f"Failed to store '{topic}' in Cognee: {e}")
            return False

    async def check_health(self) -> dict:
        """Verify tenant reachability and API-key auth.

        Per Cognee docs: a 200 on GET /health means the service is up, and
        GET /api/v1/datasets/ returns 200 (valid key), 401 (bad key) or
        404/5xx (wrong/unavailable URL).
        """
        if not self.enabled:
            return {
                "enabled": False,
                "configured": False,
                "reachable": False,
                "message": "Cognee API key not configured — memory layer is in stub/dry-run mode.",
            }

        async with httpx.AsyncClient() as client:
            try:
                health_resp = await client.get(f"{self.base_url}/health", timeout=15.0)
                datasets_resp = await client.get(
                    f"{self.base_url}/api/v1/datasets/",
                    headers={"X-Api-Key": self.api_key},
                    timeout=15.0,
                )
            except Exception as e:
                return {
                    "enabled": True,
                    "configured": True,
                    "reachable": False,
                    "error": str(e),
                }

        return {
            "enabled": True,
            "configured": True,
            "reachable": health_resp.status_code == 200,
            "health_status": health_resp.status_code,
            "datasets_status": datasets_resp.status_code,
            "auth_valid": datasets_resp.status_code == 200,
            "base_url": self.base_url,
            "brain_name": self.brain_name,
        }

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

        results = await self._recall(
            query=(
                f"developer profile metadata weaknesses strengths mistakes "
                f"user_{user_id}"
            ),
            search_type="GRAPH_COMPLETION",
        )
        return {"results": results}

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
        return await self._recall(
            query=f"For repository {repo_name}: {query}",
            search_type="HYBRID_COMPLETION",
        )

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

        results = await self._recall(
            query=(
                f"Summarize all code review scores, mistakes, improvements, "
                f"and skill progress for user {user_id} from the past week. "
                f"Include security, performance, architecture, and maintainability trends."
            ),
            search_type="GRAPH_COMPLETION",
        )
        return {"results": results}

    async def ask_codebase(self, user_id: str, question: str) -> str:
        if not self.enabled:
            return "Cognee is not configured. Cannot search codebase."

        results = await self._recall(
            query=question,
            search_type="HYBRID_COMPLETION",
            top_k=5,
        )
        if not results:
            return "No results found for your question."
        return "\n\n".join(results)[:6000]

    async def get_skill_badges(self, user_id: str) -> dict:
        if not self.enabled:
            return {"results": []}

        results = await self._recall(
            query=(
                f"List all code review scores for user {user_id}. "
                f"Include security_score, performance_score, "
                f"architecture_score, and maintainability_score from every "
                f"review session. Return the raw data."
            ),
            search_type="GRAPH_COMPLETION",
        )
        return {"results": results}
