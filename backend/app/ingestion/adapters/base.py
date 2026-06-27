from abc import ABC, abstractmethod
from typing import List, AsyncGenerator
from backend.app.ingestion.models import NormalizedItem


class BaseSourceAdapter(ABC):
    """
    Base class for all Source Hub adapters.
    Ensures that adding or removing sources never affects the rest of the system.
    """

    @property
    @abstractmethod
    def source_id(self) -> str:
        """Identifier for the source (e.g., 'github_trending', 'producthunt')"""
        pass

    @abstractmethod
    async def fetch(self) -> AsyncGenerator[NormalizedItem, None]:
        """
        Fetches data from the source and yields NormalizedItem objects.
        Must respect rate limits, cache headers (ETag, Last-Modified), and free-tier quotas.
        """
        pass
        # Yield NormalizedItem objects
        yield None  # Satisfy type checker for abstract method
