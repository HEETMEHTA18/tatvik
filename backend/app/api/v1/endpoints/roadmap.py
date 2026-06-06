import json
import logging
from typing import Optional
import httpx
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import select
from pydantic import BaseModel

from app.api.deps import get_current_user_id, get_db
from app.core.config import settings
from app.models.entities import Repository, Roadmap, DeveloperScore
from app.models.user import User
from app.api.v1.endpoints.advanced import call_ai_json

logger = logging.getLogger(__name__)
router = APIRouter()


class RoadmapGenerateRequest(BaseModel):
    goal: Optional[str] = None
    preferred_stack: Optional[str] = None


@router.post("/generate")
async def generate_roadmap(
    payload: Optional[RoadmapGenerateRequest] = None,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    """
    Generate a dynamic 5-step career roadmap for the user based on their actual repositories,
    languages, developer score, and personal goals / target tech stack, and save it to the database.
    """
    # 1. Fetch repositories and user profile info
    stmt = select(Repository).where(Repository.user_id == user_id)
    repos = db.scalars(stmt).all()
    repo_list_str = (
        ", ".join([f"{r.name} ({r.language or 'General'})" for r in repos])
        if repos
        else "No repositories synced yet"
    )

    score_stmt = select(DeveloperScore).where(DeveloperScore.user_id == user_id)
    score_rec = db.scalar(score_stmt)
    score = score_rec.score if score_rec else 50

    user_stmt = select(User).where(User.id == user_id)
    user_rec = db.scalar(user_stmt)
    user_name = user_rec.name if user_rec else "Developer"

    goal = payload.goal if payload else None
    preferred_stack = payload.preferred_stack if payload else None

    # 2. Build AI prompt
    prompt = (
        f"You are a Senior Engineering Director and Career Coach.\n"
        f"Analyze this developer's profile to create a custom roadmap:\n"
        f"- Name: {user_name}\n"
        f"- GitHub Repositories: {repo_list_str}\n"
        f"- Developer Rating: {score}/10.0\n"
    )
    if goal:
        prompt += f"- Career Goal: {goal}\n"
    if preferred_stack:
        prompt += f"- Target/Preferred Tech Stack: {preferred_stack}\n"

    prompt += (
        f"\nGenerate a customized, highly professional, realistic 5-step career roadmap for them to reach the next level.\n"
        f"The milestones must be highly specific to their tech stack (based on their repositories and target preferred stack).\n"
        f"Do NOT output generic, unrelated, or random tasks. Focus strictly on their target technologies and goals.\n\n"
        f"Return your response strictly as a JSON object with these exact keys:\n"
        f"{{\n"
        f'  "title": "Roadmap path name (e.g. Flutter Developer to Senior Mobile Architect)",\n'
        f'  "milestones": [\n'
        f"    {{\n"
        f'      "title": "Milestone Title (e.g. Master State Management & Performance)",\n'
        f'      "description": "Specific actions to take (e.g. Optimize rendering, implement BLoC/Riverpod, write integration tests)"\n'
        f"    }}\n"
        f"  ]\n"
        f"}}"
    )

    title = "Senior Developer Career Roadmap"
    milestones = []

    try:
        res_json = await call_ai_json(prompt)
        if res_json:
            title = res_json.get("title") or "Senior Developer Career Roadmap"
            milestones = res_json.get("milestones") or []
    except Exception as e:
        logger.error(f"Error calling AI for roadmap generation: {e}")

    # Fallback if AI call failed or returned empty list
    if not milestones:
        title = "Senior Developer Career Path"
        milestones = [
            {
                "title": "Master Core Architecture",
                "description": "Learn clean design patterns, state management, and write unit tests.",
            },
            {
                "title": "Advanced Framework Implementations",
                "description": "Build high-performance components and optimize layout render passes.",
            },
            {
                "title": "Testing & Quality Assurance",
                "description": "Achieve 80%+ coverage with unit, widget, and integration tests.",
            },
            {
                "title": "CI/CD & Cloud Deployments",
                "description": "Automate build and deployment pipelines using GitHub Actions or Codemagic.",
            },
            {
                "title": "System Design & Scaling",
                "description": "Understand distributed system patterns, offline storage synchronization, and local caching.",
            },
        ]

    # 3. Save roadmap to the database (upsert active roadmap)
    roadmap_stmt = select(Roadmap).where(
        Roadmap.user_id == user_id, Roadmap.status == "active"
    )
    db_roadmap = db.scalar(roadmap_stmt)
    if not db_roadmap:
        db_roadmap = Roadmap(user_id=user_id, status="active")

    db_roadmap.title = title
    db_roadmap.milestones = json.dumps(milestones)
    db.add(db_roadmap)
    db.commit()
    db.refresh(db_roadmap)

    return {
        "id": db_roadmap.id,
        "user_id": db_roadmap.user_id,
        "title": db_roadmap.title,
        "milestones": milestones,
        "status": db_roadmap.status,
    }


@router.get("/current")
async def current_roadmap(
    user_id: str = Depends(get_current_user_id), db: Session = Depends(get_db)
):
    """
    Get the active career roadmap for the authenticated user.
    If no roadmap exists, automatically trigger generation on the fly.
    """
    roadmap_stmt = select(Roadmap).where(
        Roadmap.user_id == user_id, Roadmap.status == "active"
    )
    db_roadmap = db.scalar(roadmap_stmt)

    if db_roadmap and db_roadmap.milestones:
        try:
            milestones = json.loads(db_roadmap.milestones)
            return {
                "id": db_roadmap.id,
                "user_id": db_roadmap.user_id,
                "title": db_roadmap.title,
                "milestones": milestones,
                "status": db_roadmap.status,
            }
        except Exception:
            pass

    # If not found or JSON decode failed, generate dynamically
    return await generate_roadmap(user_id=user_id, db=db)
