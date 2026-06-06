from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import get_db
from app.repositories.user_repository import UserRepository
from app.services.auth_service import AuthService
from app.services.user_service import UserService

bearer_scheme = HTTPBearer(auto_error=True)


def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    return AuthService(user_repository=UserRepository(db))


def get_user_service(db: Session = Depends(get_db)) -> UserService:
    return UserService(user_repository=UserRepository(db))


def get_current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> str:
    token = credentials.credentials
    try:
        payload = jwt.decode(
            token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm]
        )
        sub = payload.get("sub")
        if not sub:
            raise ValueError("missing subject")
        return str(sub)
    except (JWTError, ValueError) as exc:
        raise ValueError("Invalid or expired token") from exc
