from fastapi import APIRouter

from app.api.v1.endpoints import (
    advanced,
    analysis,
    auth,
    github,
    mentor,
    recommendations,
    repositories,
    roadmap,
    users,
    prompts,
)

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(github.router, prefix="/github", tags=["github"])
api_router.include_router(
    repositories.router, prefix="/repositories", tags=["repositories"]
)
api_router.include_router(analysis.router, prefix="/analysis", tags=["analysis"])
api_router.include_router(roadmap.router, prefix="/roadmap", tags=["roadmap"])
api_router.include_router(mentor.router, prefix="/mentor", tags=["mentor"])
api_router.include_router(
    recommendations.router, prefix="/recommendations", tags=["recommendations"]
)
api_router.include_router(advanced.router, prefix="/advanced", tags=["advanced"])
api_router.include_router(prompts.router, prefix="/prompts", tags=["prompts"])
