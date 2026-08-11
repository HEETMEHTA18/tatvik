from pydantic import BaseModel, HttpUrl, Field
from typing import List, Optional, Dict, Any
from datetime import datetime


class NormalizedItem(BaseModel):
    id: str = Field(..., description="Unique identifier for the item")
    source: str = Field(
        ..., description="Source identifier (e.g., 'github', 'producthunt')"
    )
    type: str = Field(
        ..., description="Type of content (e.g., 'repository', 'article', 'release')"
    )
    title: str = Field(..., description="Title of the content")
    url: HttpUrl = Field(..., description="URL to the original content")
    author: Optional[str] = Field(None, description="Author or creator")
    publishedAt: datetime = Field(..., description="Publication date and time")
    category: Optional[str] = Field(None, description="High-level category")
    tags: List[str] = Field(
        default_factory=list, description="Associated tags or keywords"
    )
    summary: Optional[str] = Field(None, description="Brief summary of the content")
    image: Optional[HttpUrl] = Field(None, description="Preview image URL")
    metadata: Dict[str, Any] = Field(
        default_factory=dict, description="Source-specific metadata"
    )
