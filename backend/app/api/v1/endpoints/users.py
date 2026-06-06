from fastapi import APIRouter, Depends, HTTPException, status

from app.api.deps import get_current_user_id, get_user_service
from app.schemas.user import UserResponse
from app.services.user_service import UserService

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
