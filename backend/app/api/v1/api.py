from fastapi import APIRouter

from app.api.v1.endpoints import (
    advanced,
    analysis,
    auth,
    github,
    intelligence,
    mentor,
    notifications,
    openclaw,
    recommendations,
    repositories,
    roadmap,
    users,
    prompts,
    research,
    timeline,
    reviewer,
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
api_router.include_router(
    notifications.router, prefix="/notifications", tags=["notifications"]
)
api_router.include_router(research.router, prefix="/research", tags=["research"])
api_router.include_router(timeline.router, prefix="/timeline", tags=["timeline"])
api_router.include_router(reviewer.router, prefix="/reviewer", tags=["reviewer"])
api_router.include_router(
    intelligence.router, prefix="/intelligence", tags=["intelligence"]
)
# ── OpenClaw Universal Automation Runtime ──────────────────────────────────
api_router.include_router(
    openclaw.router, prefix="/openclaw", tags=["openclaw"]
)
