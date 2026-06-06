from app.core.exceptions import ApiException
from app.repositories.user_repository import UserRepository


class UserService:
    def __init__(self, user_repository: UserRepository):
        self.user_repository = user_repository

    def get_current_user(self, user_id: str):
        user = self.user_repository.get_by_id(user_id)
        if not user:
            raise ApiException(
                code="USER_NOT_FOUND", message="User not found", status_code=404
            )
        return user
