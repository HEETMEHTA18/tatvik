from typing import Any, Dict
from backend.app.tatvik.agents.base import TatvikAgent


class CareerAgent(TatvikAgent):
    @property
    def name(self) -> str:
        return "Career"

    @property
    def responsibility(self) -> str:
        return "Maps technologies to career opportunities."

    async def process(self, context: Dict[str, Any], payload: Any) -> Any:
        # Implementation for Career
        pass
