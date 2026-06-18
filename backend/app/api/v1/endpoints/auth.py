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


@router.get("/google/authorize")
def google_authorize(token: str, request: Request):
    from jose import jwt
    import urllib.parse
    from fastapi.responses import RedirectResponse
    from fastapi import HTTPException
    from app.core.config import settings

    try:
        payload = jwt.decode(
            token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm]
        )
        user_id = payload.get("sub")
        if not user_id:
            raise ValueError()
    except Exception:
        raise HTTPException(status_code=401, detail="Unauthorized")

    host_header = request.headers.get("host", "localhost:8000")
    is_local = any(
        x in host_header for x in ["localhost", "127.0.0.1", "172.", "192.168."]
    )
    scheme = "https" if not is_local else "http"
    redirect_uri = f"{scheme}://{host_header}/api/v1/auth/google/callback"

    scopes = [
        "https://www.googleapis.com/auth/drive.file",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile",
    ]
    scope_str = " ".join(scopes)

    params = {
        "client_id": settings.GOOGLE_CLIENT_ID or "google-client-id",
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": scope_str,
        "access_type": "offline",
        "prompt": "consent",
        "state": token,
    }

    auth_url = "https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode(
        params
    )
    return RedirectResponse(url=auth_url)


@router.get("/google/callback")
async def google_callback(
    code: str, state: str, request: Request, db: Session = Depends(get_db)
):
    import httpx
    from fastapi.responses import RedirectResponse
    from jose import jwt
    from app.core.config import settings
    from app.models.entities import GoogleProfile
    from sqlalchemy import select

    host_header = request.headers.get("host", "localhost:8000")
    is_local = any(
        x in host_header for x in ["localhost", "127.0.0.1", "172.", "192.168."]
    )
    if is_local:
        frontend_base = f"http://{host_header.replace('8000', '8080')}"
    else:
        frontend_base = "https://devsmentor.vercel.app"

    try:
        payload = jwt.decode(
            state, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm]
        )
        user_id = payload.get("sub")
        if not user_id:
            raise ValueError()
    except Exception:
        return RedirectResponse(
            url=f"{frontend_base}/?gdrive=error&message=invalid_auth_state"
        )

    scheme = "https" if not is_local else "http"
    redirect_uri = f"{scheme}://{host_header}/api/v1/auth/google/callback"

    async with httpx.AsyncClient() as client:
        token_response = await client.post(
            "https://oauth2.googleapis.com/token",
            data={
                "client_id": settings.GOOGLE_CLIENT_ID or "google-client-id",
                "client_secret": settings.GOOGLE_CLIENT_SECRET
                or "google-client-secret",
                "code": code,
                "grant_type": "authorization_code",
                "redirect_uri": redirect_uri,
            },
        )
        token_data = token_response.json()
        access_token = token_data.get("access_token")
        refresh_token = token_data.get("refresh_token")

        if not access_token:
            return RedirectResponse(
                url=f"{frontend_base}/?gdrive=error&message=no_access_token"
            )

        profile_response = await client.get(
            "https://www.googleapis.com/oauth2/v2/userinfo",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        google_user = profile_response.json()
        email = google_user.get("email") or "google-user@devmentor.com"

        stmt = select(GoogleProfile).where(GoogleProfile.user_id == user_id)
        profile = db.scalar(stmt)
        if not profile:
            profile = GoogleProfile(
                user_id=user_id,
                email=email,
                access_token=access_token,
                refresh_token=refresh_token,
            )
            db.add(profile)
        else:
            profile.email = email
            profile.access_token = access_token
            if refresh_token:
                profile.refresh_token = refresh_token
        db.commit()

    return RedirectResponse(url=f"{frontend_base}/?gdrive=success")


@router.get("/google/status")
def google_status(request: Request, db: Session = Depends(get_db)):
    from app.api.deps import get_current_user_id
    from app.models.entities import GoogleProfile
    from sqlalchemy import select

    # Extract token from header to manually authenticate
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return {"connected": False, "email": None}

    token = auth_header.split(" ")[1]
    from jose import jwt
    from app.core.config import settings

    try:
        payload = jwt.decode(
            token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm]
        )
        user_id = payload.get("sub")
    except Exception:
        return {"connected": False, "email": None}

    stmt = select(GoogleProfile).where(GoogleProfile.user_id == user_id)
    profile = db.scalar(stmt)
    if profile:
        return {"connected": True, "email": profile.email}
    return {"connected": False, "email": None}


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
                url=f"{frontend_base}/login?error=github_token_failed"
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
        frontend_url = f"{frontend_base}/?token={system_token}&username={login}"
        return RedirectResponse(url=frontend_url)
