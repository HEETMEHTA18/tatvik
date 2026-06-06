from fastapi import APIRouter, Depends

from app.api.deps import get_current_user_id

router = APIRouter()


@router.get("/repositories")
def repository_recommendations(user_id: str = Depends(get_current_user_id)):
    return {"user_id": user_id, "items": []}


@router.get("/projects")
def project_recommendations(user_id: str = Depends(get_current_user_id)):
    return {"user_id": user_id, "items": []}


@router.get("/open-source")
def open_source_recommendations(user_id: str = Depends(get_current_user_id)):
    return {"user_id": user_id, "items": []}
