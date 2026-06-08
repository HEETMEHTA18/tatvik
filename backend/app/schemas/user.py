from pydantic import BaseModel, EmailStr
from typing import Optional


class UserResponse(BaseModel):
    id: str
    email: EmailStr
    name: str
    username: Optional[str] = None
    avatar_url: Optional[str] = None
    personal_goal: Optional[str] = None
    preferred_stack: Optional[str] = None

    class Config:
        from_attributes = True


class DeveloperMemoryUpdateRequest(BaseModel):
    personal_goal: str
    preferred_stack: str
