from typing import Any, Dict
from backend.app.tatvik.agents.base import TatvikAgent


class MentorAgent(TatvikAgent):
    @property
    def name(self) -> str:
        return "Mentor"

    @property
    def responsibility(self) -> str:
        return "Explains concepts."

    async def process(self, context: Dict[str, Any], payload: Any) -> Any:
        # Implementation for Mentor
        pass
