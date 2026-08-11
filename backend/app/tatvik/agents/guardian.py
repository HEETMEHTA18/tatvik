from typing import Any, Dict
from backend.app.tatvik.agents.base import TatvikAgent


class GuardianAgent(TatvikAgent):
    @property
    def name(self) -> str:
        return "Guardian"

    @property
    def responsibility(self) -> str:
        return "Monitors security advisories."

    async def process(self, context: Dict[str, Any], payload: Any) -> Any:
        # Implementation for Guardian
        pass
