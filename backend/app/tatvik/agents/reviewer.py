from typing import Any, Dict
from backend.app.tatvik.agents.base import TatvikAgent


class ReviewerAgent(TatvikAgent):
    @property
    def name(self) -> str:
        return "Reviewer"

    @property
    def responsibility(self) -> str:
        return "Detects duplicates and verifies quality."

    async def process(self, context: Dict[str, Any], payload: Any) -> Any:
        # Implementation for Reviewer
        pass
