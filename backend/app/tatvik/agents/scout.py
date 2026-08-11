from typing import Any, Dict
from backend.app.tatvik.agents.base import TatvikAgent


class ScoutAgent(TatvikAgent):
    @property
    def name(self) -> str:
        return "Scout"

    @property
    def responsibility(self) -> str:
        return "Discovers information."

    async def process(self, context: Dict[str, Any], payload: Any) -> Any:
        # Implementation for Scout
        pass
