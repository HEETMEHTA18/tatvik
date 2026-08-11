from typing import Any, Dict
from backend.app.tatvik.agents.base import TatvikAgent


class MemoryAgent(TatvikAgent):
    @property
    def name(self) -> str:
        return "Memory"

    @property
    def responsibility(self) -> str:
        return "Uses Cognee to remember knowledge."

    async def process(self, context: Dict[str, Any], payload: Any) -> Any:
        # Implementation for Memory
        pass
