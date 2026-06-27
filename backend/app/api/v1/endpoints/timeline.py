import logging
from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.api.deps import get_current_user_id, get_db
from app.models.entities import (
    PromptHistory,
    AutoDevSession,
    Repository,
    MentorChat,
)
from app.services.cognee_service import CogneeService

logger = logging.getLogger(__name__)
router = APIRouter()
_cognee_service = CogneeService()


@router.get("/")
async def get_developer_timeline(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    limit: int = 50,
):
    """
    Returns a unified, chronological timeline of everything the developer has done.
    This aggregates Git commits (via AutoDev sessions), AI prompts, mentor conversations,
    and repository creations to build a seamless "Developer Timeline".
    """
    try:
        timeline = []

        # 1. Fetch AI Prompt History
        stmt_prompts = (
            select(PromptHistory)
            .where(PromptHistory.user_id == user_id)
            .order_by(PromptHistory.created_at.desc())
            .limit(limit)
        )
        prompts = db.scalars(stmt_prompts).all()
        for p in prompts:
            timeline.append(
                {
                    "type": "prompt",
                    "id": p.id,
                    "title": "Used AI Prompt",
                    "description": p.original_prompt,
                    "workflow": p.workflow,
                    "technologies": (
                        [t.strip() for t in p.technologies.split(",") if t.strip()]
                        if p.technologies
                        else []
                    ),
                    "project_name": p.project_name,
                    "score": p.score,
                    "timestamp": p.created_at.isoformat(),
                    "date_obj": p.created_at,
                }
            )

        # 2. Fetch AutoDev Sessions (Coding / Commits)
        stmt_sessions = (
            select(AutoDevSession)
            .where(AutoDevSession.user_id == user_id)
            .order_by(AutoDevSession.start_time.desc())
            .limit(limit)
        )
        sessions = db.scalars(stmt_sessions).all()
        for s in sessions:
            timeline.append(
                {
                    "type": "coding_session",
                    "id": s.id,
                    "title": "Coding Session",
                    "description": f"Worked on {s.project_name} (branch: {s.branch})",
                    "commit_sha": s.commit_sha,
                    "languages": (
                        [l.strip() for l in s.languages.split(",") if l.strip()]
                        if s.languages
                        else []
                    ),
                    "timestamp": s.start_time.isoformat(),
                    "date_obj": s.start_time,
                }
            )

        # 3. Fetch Synced Repositories (OSS Contributions)
        stmt_repos = (
            select(Repository)
            .where(Repository.user_id == user_id)
            .order_by(Repository.synced_at.desc())
            .limit(limit)
        )
        repos = db.scalars(stmt_repos).all()
        for r in repos:
            timeline.append(
                {
                    "type": "repository",
                    "id": r.id,
                    "title": "Repository Synced",
                    "description": f"Synced repository {r.full_name}",
                    "language": r.language,
                    "stars": r.stars_count,
                    "timestamp": r.synced_at.isoformat(),
                    "date_obj": r.synced_at,
                }
            )

        # 4. Fetch Cognee Graph Memories (Architecture Decisions / Insights)
        try:
            memory = await _cognee_service.get_developer_profile(user_id)
            if memory and "results" in memory:
                # We don't have exact timestamps for Cognee abstract nodes in this response format easily,
                # but we can try to surface them. For now, we mock the timestamp for high-level graph memory.
                # In a full implementation, we would query the specific temporal edges from Cognee.
                timeline.append(
                    {
                        "type": "memory_graph",
                        "id": "cognee_graph",
                        "title": "Memory Graph Checkpoint",
                        "description": str(memory["results"])[:200] + "...",
                        "timestamp": datetime.utcnow().isoformat(),
                        "date_obj": datetime.utcnow(),
                    }
                )
        except Exception as e:
            logger.warning(
                "Failed to fetch Cognee memory for timeline due to an internal error."
            )

        # Sort the unified timeline descending by date
        timeline.sort(key=lambda x: x["date_obj"], reverse=True)

        # Remove the internal date object before returning
        for item in timeline:
            del item["date_obj"]

        return {"success": True, "timeline": timeline[:limit]}
    except Exception as e:
        logger.error(f"Error fetching developer timeline: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An internal error occurred while fetching the developer timeline.",
        )
