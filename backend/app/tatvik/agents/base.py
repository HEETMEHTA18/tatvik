from abc import ABC, abstractmethod
from typing import Any, Dict


class TatvikAgent(ABC):
    """
    Base class for all Tatvik agents in the Multi-Agent System.
    """

    @property
    @abstractmethod
    def name(self) -> str:
        """Name of the agent (e.g., 'Scout', 'Scholar', 'Mentor')"""
        pass

    @property
    @abstractmethod
    def responsibility(self) -> str:
        """Brief description of the agent's responsibility."""
        pass

    @abstractmethod
    async def process(self, context: Dict[str, Any], payload: Any) -> Any:
        """
        Process the given payload based on the agent's specific responsibility.
        """
        pass
