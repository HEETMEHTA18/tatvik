from fastapi import APIRouter, Depends

from app.api.deps import get_current_user_id

router = APIRouter()


@router.get("")
def list_repositories(user_id: str = Depends(get_current_user_id)):
    return {"items": [], "user_id": user_id}


@router.get("/{repository_id}")
def get_repository(repository_id: str, user_id: str = Depends(get_current_user_id)):
    return {"repository_id": repository_id, "user_id": user_id}


@router.post("/{repository_id}/analyze")
def analyze_repository(repository_id: str, user_id: str = Depends(get_current_user_id)):
    return {
        "message": "Analysis queued",
        "repository_id": repository_id,
        "user_id": user_id,
    }
