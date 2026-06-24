import os
import logging
from app.core.config import settings

logger = logging.getLogger(__name__)

class CogneeService:
    def __init__(self):
        """
        Initializes Cognee Cloud connection and configures target LLM/Vector store credentials.
        """
        self.api_key = settings.cognee_api_key
        
        # Cognee relies on environment variables set during module initialization
        if self.api_key:
            os.environ["COGNEE_API_KEY"] = self.api_key
        
        # Configure target LLM provider to use Gemini (prevents falling back to OpenAI)
        if settings.gemini_api_key:
            os.environ["LLM_API_KEY"]      = settings.gemini_api_key
            os.environ["LLM_PROVIDER"]     = "gemini"
            os.environ["LLM_MODEL"]         = "gemini/gemini-2.0-flash"
            os.environ["EMBEDDING_PROVIDER"] = "gemini"
            os.environ["EMBEDDING_MODEL"]    = "models/text-embedding-004"
        
        self.enabled = bool(self.api_key)
        if not self.enabled:
            logger.warning("Cognee API Key is not configured. Cognee memory layer will operate in stub/dry-run mode.")

    async def add_developer_profile(self, user_id: str, profile_data: dict) -> bool:
        """
        Saves user developer strengths, weaknesses, mistakes, and project history into the long-term memory graph.
        """
        if not self.enabled:
            logger.info(f"[Stub] Added developer profile for user {user_id}: {profile_data}")
            return True
            
        try:
            import cognee
            text_payload = (
                f"Developer profile for user {user_id}: "
                + str(profile_data)
            )
            await cognee.add(text_payload, dataset_name=f"user_{user_id}")
            await cognee.cognify(datasets=[f"user_{user_id}"])
            return True
        except Exception as e:
            logger.exception(f"Failed to add developer profile to Cognee: {e}")
            return False

    async def get_developer_profile(self, user_id: str) -> dict:
        """
        Retrieves the long-term developer profile and mistake list from the memory layer.
        """
        if not self.enabled:
            logger.info(f"[Stub] Get developer profile for user {user_id}")
            return {"message": "Cognee API key not set. Using local database profile instead."}
            
        try:
            import cognee
            results = await cognee.search(
                f"developer profile metadata weaknesses strengths mistakes user_{user_id}"
            )
            return {"results": results}
        except Exception as e:
            logger.exception(f"Failed to query Cognee developer profile: {e}")
            return {"error": str(e)}

    async def index_repository(self, user_id: str, repo_name: str, codebase_files: list[dict]) -> bool:
        """
        Ingests codebase metadata, architecture files (prompts.md, logs.md, todos.md), and directory maps.
        """
        if not self.enabled:
            logger.info(f"[Stub] Indexing repository {repo_name} with {len(codebase_files)} files for user {user_id}")
            return True
            
        try:
            import cognee
            texts = [
                f"File {file.get('path')}: {file.get('content', '')}"
                for file in codebase_files
            ]
            combined = "\n\n".join(texts)
            await cognee.add(combined, dataset_name=f"repo_{user_id}_{repo_name}")
            await cognee.cognify(datasets=[f"repo_{user_id}_{repo_name}"])
            return True
        except Exception as e:
            logger.exception(f"Failed to index repository on Cognee: {e}")
            return False

    async def query_repository_memory(self, user_id: str, repo_name: str, query: str) -> list:
        """
        Performs vector-graph search over the repo memory to explain code patterns or search architecture.
        """
        if not self.enabled:
            logger.info(f"[Stub] Querying repository {repo_name} for user {user_id}: {query}")
            return []
            
        try:
            import cognee
            return await cognee.search(query)
        except Exception as e:
            logger.exception(f"Failed to query Cognee repository memory: {e}")
            return []
