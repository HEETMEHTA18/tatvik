from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session
from app.db.session import get_db

from app.api.deps import get_auth_service
from app.schemas.auth import LoginRequest, RegisterRequest, TokenResponse
from app.services.auth_service import AuthService

router = APIRouter()


@router.post("/register", response_model=TokenResponse)
def register(
    payload: RegisterRequest, service: AuthService = Depends(get_auth_service)
):
    token = service.register(
        email=payload.email, password=payload.password, name=payload.name
    )
    return TokenResponse(access_token=token)


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, service: AuthService = Depends(get_auth_service)):
    token = service.login(email=payload.email, password=payload.password)
    return TokenResponse(access_token=token)


@router.post("/github", response_model=TokenResponse)
def github_oauth_stub():
    return TokenResponse(access_token="github-oauth-stub-token")


@router.post("/google", response_model=TokenResponse)
def google_oauth_stub():
    return TokenResponse(access_token="google-oauth-stub-token")


@router.get("/github/callback")
async def github_callback(code: str, request: Request, db: Session = Depends(get_db)):
    import httpx
    from fastapi.responses import RedirectResponse
    from app.core.security import get_password_hash, create_access_token
    from app.repositories.user_repository import UserRepository
    from app.services.github_service import GithubService

    async with httpx.AsyncClient() as client:
        # 1. Exchange code for access token
        token_response = await client.post(
            "https://github.com/login/oauth/access_token",
            data={
                "client_id": "Ov23liN1MaudLGibnAcW",
                "client_secret": "46f1d1d00cb45d6e2071cafa3434235172d38ab7",
                "code": code,
            },
            headers={"Accept": "application/json"},
        )
        token_data = token_response.json()
        access_token = token_data.get("access_token")
        if not access_token:
            host_header = request.headers.get("host", "localhost:8000")
            is_local = any(
                x in host_header for x in ["localhost", "127.0.0.1", "172.", "192.168."]
            )
            if is_local:
                frontend_base = f"http://{host_header.replace('8000', '8080')}"
            else:
                frontend_base = "https://devsmentor.vercel.app"
            return RedirectResponse(
                url=f"{frontend_base}/#/login?error=github_token_failed"
            )

        # 2. Get user info from GitHub
        user_response = await client.get(
            "https://api.github.com/user",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        github_user = user_response.json()
        login = github_user.get("login")
        name = github_user.get("name") or login
        email = github_user.get("email") or f"{login}@github.com"

        # 3. Find or create user
        user_repo = UserRepository(db)
        user = user_repo.get_by_email(email)
        if not user:
            user = user_repo.create(
                email=email,
                name=name,
                hashed_password=get_password_hash("oauth-stub-password"),
            )
            user.username = login
            user.avatar_url = github_user.get("avatar_url")
            db.commit()
            db.refresh(user)
        else:
            user.name = name or user.name
            user.username = login or user.username
            user.avatar_url = github_user.get("avatar_url") or user.avatar_url
            db.commit()
            db.refresh(user)

        # 4. Sync GitHub profile & repositories to local database
        try:
            github_service = GithubService(db)
            await github_service.sync_user_github_data(
                user_id=user.id, access_token=access_token
            )
        except Exception as e:
            db.rollback()
            # log the exception but allow login to continue
            import logging

            logging.getLogger(__name__).error(
                f"Error syncing github data on callback: {e}"
            )

        # 5. Generate system access token
        system_token = create_access_token(subject=user.id)

        # 6. Redirect back to frontend
        host_header = request.headers.get("host", "localhost:8000")
        is_local = any(
            x in host_header for x in ["localhost", "127.0.0.1", "172.", "192.168."]
        )
        if is_local:
            frontend_base = f"http://{host_header.replace('8000', '8080')}"
        else:
            frontend_base = "https://devsmentor.vercel.app"
        frontend_url = f"{frontend_base}/#/app?token={system_token}&username={login}"
        return RedirectResponse(url=frontend_url)
