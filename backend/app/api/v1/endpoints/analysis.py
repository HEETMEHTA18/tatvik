from fastapi import APIRouter, Depends

from app.api.deps import get_current_user_id

router = APIRouter()


@router.post("/run")
def run_analysis(user_id: str = Depends(get_current_user_id)):
    return {"message": "Analysis started", "user_id": user_id}


@router.get("/latest")
def latest_analysis(user_id: str = Depends(get_current_user_id)):
    return {
        "user_id": user_id,
        "developer_score": 82,
        "strengths": ["consistency", "documentation"],
        "gaps": ["system design"],
    }
