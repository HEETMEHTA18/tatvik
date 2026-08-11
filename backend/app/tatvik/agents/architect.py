from typing import Any, Dict
from backend.app.tatvik.agents.base import TatvikAgent


class ArchitectAgent(TatvikAgent):
    @property
    def name(self) -> str:
        return "Architect"

    @property
    def responsibility(self) -> str:
        return "Builds relationships."

    async def process(self, context: Dict[str, Any], payload: Any) -> Any:
        # Implementation for Architect
        pass
