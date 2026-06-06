from app.core.exceptions import ApiException
from app.core.security import create_access_token, get_password_hash, verify_password
from app.repositories.user_repository import UserRepository


class AuthService:
    def __init__(self, user_repository: UserRepository):
        self.user_repository = user_repository

    def register(self, email: str, password: str, name: str) -> str:
        existing = self.user_repository.get_by_email(email)
        if existing:
            raise ApiException(code="AUTH_EMAIL_EXISTS", message="Email already in use")
        hashed_password = get_password_hash(password)
        user = self.user_repository.create(
            email=email, name=name, hashed_password=hashed_password
        )
        return create_access_token(subject=user.id)

    def login(self, email: str, password: str) -> str:
        user = self.user_repository.get_by_email(email)
        if not user or not verify_password(password, user.hashed_password):
            raise ApiException(
                code="AUTH_INVALID_CREDENTIALS", message="Invalid credentials"
            )
        return create_access_token(subject=user.id)
