from fastapi import APIRouter, Depends, HTTPException, status
from app.api.deps import get_current_user_id, get_user_service, get_db
from app.schemas.user import UserResponse, DeveloperMemoryUpdateRequest
from app.services.user_service import UserService
from sqlalchemy.orm import Session
from sqlalchemy import select
from app.models.user import User

router = APIRouter()


@router.get("/me", response_model=UserResponse)
def get_me(
    user_id: str = Depends(get_current_user_id),
    service: UserService = Depends(get_user_service),
):
    try:
        return service.get_current_user(user_id)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)
        ) from exc


@router.post("/memory", response_model=UserResponse)
def update_developer_memory(
    payload: DeveloperMemoryUpdateRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    stmt = select(User).where(User.id == user_id)
    user = db.scalar(stmt)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.personal_goal = payload.personal_goal
    user.preferred_stack = payload.preferred_stack
    db.commit()
    db.refresh(user)
    return user
