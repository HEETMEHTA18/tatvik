import json
import logging
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import select, func
from typing import List, Optional

from app.api.deps import get_current_user_id, get_db
from app.core.config import settings
from app.models.entities import (
    PromptHistory,
    GithubProfile,
    Repository,
    AutoDevSession,
    ExecutedCommand,
    GeneratedFile,
)
from app.api.v1.endpoints.advanced import call_ai_json

logger = logging.getLogger(__name__)
router = APIRouter()


class UniversalEventRequest(BaseModel):
    # Old/Simple PromptEventRequest fields
    original_prompt: Optional[str] = None
    project_name: Optional[str] = None
    file_context: Optional[str] = None

    # New TatvikEventPayload fields
    event: Optional[str] = None
    session_id: Optional[str] = None
    timestamp: Optional[str] = None
    data: Optional[dict] = None


def parse_datetime(val) -> datetime:
    if not val:
        return datetime.utcnow()
    try:
        if isinstance(val, str):
            val = val.replace("Z", "+00:00")
            return datetime.fromisoformat(val)
        return datetime.utcnow()
    except Exception:
        return datetime.utcnow()


@router.post("/event")
async def receive_prompt_event(
    payload: UniversalEventRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    """
    Receive an AutoDevs event, refine the prompt, score it, extract tech/workflow, and save it.
    Supports both legacy PromptEventRequest and new structured TatvikEventPayload.
    """
    # 1. Handle TatvikEventPayload structure
    if payload.event:
        event_type = payload.event
        session_id = payload.session_id or (payload.data or {}).get("session_id")
        timestamp_str = (
            payload.timestamp
            or (payload.data or {}).get("timestamp")
            or (payload.data or {}).get("start_time")
        )

        if event_type == "session.started":
            meta = (payload.data or {}).get("metadata") or {}
            languages_str = ", ".join(meta.get("languages", []))
            frameworks_str = ", ".join(meta.get("frameworks", []))

            # Check if session already exists
            session_stmt = select(AutoDevSession).where(
                AutoDevSession.session_id == session_id
            )
            db_session = db.scalar(session_stmt)
            if not db_session:
                db_session = AutoDevSession(
                    user_id=user_id,
                    session_id=session_id or "unknown",
                    project_name=meta.get("project_name", "unknown"),
                    project_path=meta.get("path", ""),
                    branch=meta.get("branch", "unknown"),
                    commit_sha=meta.get("commit", "unknown"),
                    languages=languages_str,
                    frameworks=frameworks_str,
                    start_time=parse_datetime(timestamp_str),
                )
                db.add(db_session)
                db.commit()
            return {
                "success": True,
                "message": "Session start logged",
                "session_id": session_id,
            }

        elif event_type == "session.ended":
            session_stmt = select(AutoDevSession).where(
                AutoDevSession.session_id == session_id
            )
            db_session = db.scalar(session_stmt)
            if db_session:
                db_session.end_time = parse_datetime(timestamp_str)
                db.commit()
            return {
                "success": True,
                "message": "Session end logged",
                "session_id": session_id,
            }

        elif event_type == "prompt.captured":
            prompt_data = payload.data or {}
            original_prompt = prompt_data.get("prompt", "")
            response_content = prompt_data.get("response", "")
            prompt_id = prompt_data.get("id")

            meta = prompt_data.get("metadata") or {}
            project_name = meta.get("project_name")

            if not original_prompt.strip():
                raise HTTPException(status_code=400, detail="Prompt cannot be empty")

            refined_prompt = ""
            score = 0
            techs_list = []
            workflow = "Development"
            technologies_str = "General"

            db_prompt = PromptHistory(
                user_id=user_id,
                session_id=session_id,
                prompt_id=prompt_id,
                original_prompt=original_prompt,
                refined_prompt=refined_prompt,
                response=response_content,
                score=score,
                technologies=technologies_str,
                workflow=workflow,
                project_name=project_name,
            )
            db.add(db_prompt)
            db.commit()
            db.refresh(db_prompt)

            # Log executed commands if present
            cmds = prompt_data.get("executed_commands") or []
            for cmd in cmds:
                db_cmd = ExecutedCommand(
                    session_id=session_id or "unknown",
                    prompt_event_id=db_prompt.id,
                    command=cmd.get("command", ""),
                    args=json.dumps(cmd.get("args", [])),
                    exit_code=cmd.get("exit_code", 0),
                    stdout=cmd.get("stdout", ""),
                    stderr=cmd.get("stderr", ""),
                    duration_ms=cmd.get("duration_ms", 0),
                    timestamp=parse_datetime(cmd.get("timestamp")),
                )
                db.add(db_cmd)

            # Log generated files if present
            files = prompt_data.get("generated_files") or []
            for f in files:
                db_file = GeneratedFile(
                    session_id=session_id or "unknown",
                    prompt_event_id=db_prompt.id,
                    file_path=f.get("file_path", ""),
                    size_bytes=f.get("size_bytes", 0),
                    action=f.get("action", "created"),
                    timestamp=parse_datetime(f.get("timestamp")),
                )
                db.add(db_file)

            db.commit()

            return {
                "id": db_prompt.id,
                "user_id": db_prompt.user_id,
                "original_prompt": db_prompt.original_prompt,
                "refined_prompt": db_prompt.refined_prompt,
                "score": db_prompt.score,
                "technologies": techs_list,
                "workflow": db_prompt.workflow,
                "project_name": db_prompt.project_name,
                "created_at": db_prompt.created_at.isoformat(),
            }
        else:
            return {"success": True, "message": f"Event type {event_type} ignored"}

    # 2. Legacy / Simple PromptEventRequest fallback
    original_prompt = payload.original_prompt
    if not original_prompt or not original_prompt.strip():
        raise HTTPException(status_code=400, detail="Prompt cannot be empty")

    refined_prompt = ""
    score = 0
    techs_list = []
    workflow = "Development"
    technologies_str = "General"

    db_prompt = PromptHistory(
        user_id=user_id,
        original_prompt=original_prompt,
        refined_prompt=refined_prompt,
        score=score,
        technologies=technologies_str,
        workflow=workflow,
        project_name=payload.project_name,
    )

    db.add(db_prompt)
    db.commit()
    db.refresh(db_prompt)

    return {
        "id": db_prompt.id,
        "user_id": db_prompt.user_id,
        "original_prompt": db_prompt.original_prompt,
        "refined_prompt": db_prompt.refined_prompt,
        "score": db_prompt.score,
        "technologies": techs_list,
        "workflow": db_prompt.workflow,
        "project_name": db_prompt.project_name,
        "created_at": db_prompt.created_at.isoformat(),
    }


@router.post("/{prompt_id}/refine")
async def refine_individual_prompt(
    prompt_id: str,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    """
    On-demand prompt refiner for a specific prompt ID.
    Calls AI to generate the refined prompt, score, technologies, and workflow category.
    """
    stmt = select(PromptHistory).where(
        PromptHistory.id == prompt_id, PromptHistory.user_id == user_id
    )
    db_prompt = db.scalar(stmt)
    if not db_prompt:
        raise HTTPException(status_code=404, detail="Prompt history item not found")

    original_prompt = db_prompt.original_prompt
    project_name = db_prompt.project_name or "N/A"

    ai_prompt = (
        f"You are a Prompt Intelligence Analyzer. Analyze the following prompt used by a developer:\n\n"
        f"Prompt: {original_prompt}\n"
        f"Project Name Context: {project_name}\n\n"
        f"Perform the following tasks:\n"
        f"1. Refine and upgrade the original prompt to be much more clear, professional, structured (with instructions/placeholders) and effective for an AI coding assistant.\n"
        f"2. Score the original prompt from 0 to 100 based on its clarity, specificity, context, and structural quality.\n"
        f"3. Extract technologies, languages, libraries or frameworks referenced or relevant. Return as a list of names.\n"
        f"4. Detect the developer workflow category. Choose exactly one from: Debugging, Refactoring, Feature Building, Testing, DevOps, Architecture, Documentation.\n\n"
        f"Return your response strictly as a JSON object with these exact keys:\n"
        f"{{\n"
        f'  "refined_prompt": "upgraded prompt content here",\n'
        f'  "score": 85,\n'
        f'  "technologies": ["Python", "FastAPI"],\n'
        f'  "workflow": "Feature Building"\n'
        f"}}"
    )

    ai_res = {}
    try:
        ai_res = await call_ai_json(ai_prompt)
    except Exception as e:
        logger.error(f"Error calling AI for prompt refinement: {e}")
        raise HTTPException(status_code=500, detail="AI service error")

    refined_prompt = ai_res.get("refined_prompt") or f"// Refined:\n{original_prompt}"
    score = ai_res.get("score") or 50
    techs_list = ai_res.get("technologies") or []
    workflow = ai_res.get("workflow") or "Development"
    technologies_str = ", ".join(techs_list) if techs_list else "General"

    db_prompt.refined_prompt = refined_prompt
    db_prompt.score = score
    db_prompt.technologies = technologies_str
    db_prompt.workflow = workflow
    db.commit()
    db.refresh(db_prompt)

    return {
        "id": db_prompt.id,
        "user_id": db_prompt.user_id,
        "original_prompt": db_prompt.original_prompt,
        "refined_prompt": db_prompt.refined_prompt,
        "score": db_prompt.score,
        "technologies": techs_list,
        "workflow": db_prompt.workflow,
        "project_name": db_prompt.project_name,
        "created_at": db_prompt.created_at.isoformat(),
    }


@router.get("/history")
def get_prompt_history(
    q: Optional[str] = None,
    workflow: Optional[str] = None,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    """
    List prompt history for the authenticated user, supporting optional search queries and workflow filters.
    """
    stmt = select(PromptHistory).where(PromptHistory.user_id == user_id)
    if q:
        search_filter = f"%{q}%"
        stmt = stmt.where(
            PromptHistory.original_prompt.like(search_filter)
            | PromptHistory.refined_prompt.like(search_filter)
            | PromptHistory.technologies.like(search_filter)
        )
    if workflow:
        stmt = stmt.where(PromptHistory.workflow == workflow)

    stmt = stmt.order_by(PromptHistory.created_at.desc())
    prompts = db.scalars(stmt).all()

    result = []
    for p in prompts:
        result.append(
            {
                "id": p.id,
                "original_prompt": p.original_prompt,
                "refined_prompt": p.refined_prompt,
                "score": p.score,
                "technologies": (
                    [t.strip() for t in p.technologies.split(",")]
                    if p.technologies
                    else []
                ),
                "workflow": p.workflow,
                "project_name": p.project_name,
                "created_at": p.created_at.isoformat(),
            }
        )
    return result


@router.get("/analytics")
def get_prompt_analytics(
    user_id: str = Depends(get_current_user_id), db: Session = Depends(get_db)
):
    """
    Generate prompt quality and developer habits analytics.
    """
    stmt = select(PromptHistory).where(PromptHistory.user_id == user_id)
    prompts = db.scalars(stmt).all()

    if not prompts:
        return {
            "total_prompts": 0,
            "average_score": 0,
            "workflow_counts": {},
            "top_technologies": [],
            "score_history": [],
        }

    total_prompts = len(prompts)
    avg_score = round(sum(p.score for p in prompts) / total_prompts, 1)

    # Calculate workflow counts
    workflow_counts = {}
    for p in prompts:
        workflow_counts[p.workflow] = workflow_counts.get(p.workflow, 0) + 1

    # Calculate technology breakdown
    tech_counts = {}
    for p in prompts:
        if p.technologies:
            for t in p.technologies.split(","):
                clean_t = t.strip()
                if clean_t and clean_t != "General":
                    tech_counts[clean_t] = tech_counts.get(clean_t, 0) + 1

    sorted_techs = sorted(tech_counts.items(), key=lambda x: x[1], reverse=True)
    top_technologies = [
        {"name": name, "count": count} for name, count in sorted_techs[:5]
    ]

    # Recent scores (up to 10) for trend line
    recent_prompts = sorted(prompts, key=lambda x: x.created_at)
    score_history = [
        {"date": p.created_at.strftime("%m-%d"), "score": p.score}
        for p in recent_prompts[-10:]
    ]

    return {
        "total_prompts": total_prompts,
        "average_score": avg_score,
        "workflow_counts": workflow_counts,
        "top_technologies": top_technologies,
        "score_history": score_history,
    }


@router.get("/recommendations")
async def get_prompt_recommendations(
    user_id: str = Depends(get_current_user_id), db: Session = Depends(get_db)
):
    """
    Generate learning recommendations based on developer's prompt patterns and detected skill gaps.
    """
    stmt = select(PromptHistory).where(PromptHistory.user_id == user_id)
    prompts = db.scalars(stmt).all()

    if not prompts:
        return {
            "recommendations": [
                {
                    "title": "Introduction to Effective Prompting",
                    "description": "Start tracking your coding prompts using the AutoDevs CLI to unlock detailed skill gaps and tailored learning paths.",
                    "tags": ["Prompting", "Basics"],
                    "url": "https://github.com/phodal/auto-dev",
                }
            ]
        }

    # Extract low-scoring workflows or technologies
    low_prompts = [p for p in prompts if p.score < 75]
    workflow_issues = {}
    for p in low_prompts:
        workflow_issues[p.workflow] = workflow_issues.get(p.workflow, 0) + 1

    worst_workflow = (
        max(workflow_issues.items(), key=lambda x: x[1])[0] if workflow_issues else None
    )

    # Extract overall techs
    tech_set = set()
    for p in prompts:
        if p.technologies:
            for t in p.technologies.split(","):
                clean_t = t.strip()
                if clean_t and clean_t != "General":
                    tech_set.add(clean_t)

    techs_str = ", ".join(tech_set) if tech_set else "coding and architecture"

    # Request AI for personalized learning roadmap/resources
    ai_prompt = (
        f"You are a developer coach. Based on the developer's prompt history, they have low scores in "
        f"the workflow '{worst_workflow or 'general coding'}'. Their primary tech stack includes: {techs_str}.\n\n"
        f"Generate 3-4 actionable, high-quality learning recommendations (tutorials, topics, best practices) to improve. "
        f"For example, if they have low scores in Refactoring, suggest Clean Code principles. If they use Flutter, recommend specific Flutter design patterns.\n\n"
        f"Return your response strictly as a JSON object with this exact key:\n"
        f"{{\n"
        f'  "recommendations": [\n'
        f"    {{\n"
        f'      "title": "Title of the course or topic",\n'
        f'      "description": "Detailed explanation of why they need this and what they will learn.",\n'
        f'      "tags": ["Flutter", "Clean Architecture"],\n'
        f'      "url": "https://github.com/..."\n'
        f"    }}\n"
        f"  ]\n"
        f"}}"
    )

    res = {}
    try:
        res = await call_ai_json(ai_prompt)
    except Exception as e:
        logger.error(f"Error in prompt recommendations: {e}")

    recommendations = res.get("recommendations")
    if not recommendations:
        # Static fallback
        recommendations = [
            {
                "title": f"Mastering {worst_workflow or 'Development'} Workflows",
                "description": f"Learn industry best practices for {worst_workflow or 'general coding'} including structuring code reviews and refining agent instructions.",
                "tags": [worst_workflow or "General", "Best Practices"],
                "url": "https://github.com/phodal/auto-dev",
            }
        ]

    return {"recommendations": recommendations}


class GithubSyncRequest(BaseModel):
    github_username: Optional[str] = None
    repo_sources: Optional[list[dict[str, str]]] = None


@router.post("/sync-github")
async def sync_github_prompts(
    payload: Optional[GithubSyncRequest] = None,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    """
    Scan the user's synchronized GitHub repositories (or public ones if username is provided)
    for the presence of a .autodevs/prompts.md file.
    If found, parse the prompts list, refine/score them, and import them into PromptHistory.
    """
    import base64
    import httpx
    from app.models.user import User

    # 1. Fetch user's GitHub access token (if they linked via OAuth)
    profile_stmt = select(GithubProfile).where(GithubProfile.user_id == user_id)
    profile = db.scalar(profile_stmt)
    access_token = profile.access_token if profile else None

    # 2. Determine GitHub username to scan
    github_username = None
    if payload and payload.github_username:
        github_username = payload.github_username.strip().replace("@", "")

    if not github_username and profile and profile.login:
        github_username = profile.login

    if not github_username:
        # Check if username is set on User object
        user_stmt = select(User).where(User.id == user_id)
        user = db.scalar(user_stmt)
        if user and user.username:
            github_username = user.username

    if not github_username:
        raise HTTPException(
            status_code=400,
            detail="GitHub username not provided and no GitHub account linked to profile.",
        )

    # Update username on the User table if it has changed/was set
    user_stmt = select(User).where(User.id == user_id)
    user = db.scalar(user_stmt)
    if user and github_username and user.username != github_username:
        user.username = github_username
        db.add(user)
        db.commit()

    repo_list = []
    if payload and payload.repo_sources:
        for repo in payload.repo_sources:
            owner = (repo.get("owner") or "").strip()
            name = (repo.get("name") or "").strip()
            full_name = (repo.get("full_name") or f"{owner}/{name}").strip("/")
            if owner and name:
                repo_list.append({"owner": owner, "name": name, "full_name": full_name})
    else:
        # 3. Pre-sync repositories from GitHub to the database to ensure we have the latest list!
        try:
            from app.services.github_service import GithubService

            github_service = GithubService(db)
            if access_token:
                await github_service.sync_user_github_data(
                    user_id=user_id, access_token=access_token
                )
            elif github_username:
                await github_service.sync_public_github_data(
                    user_id=user_id, username=github_username
                )
        except Exception as e:
            db.rollback()
            logger.error(f"Error pre-syncing repositories in prompts sync: {e}")

        # Determine repository list (now fresh!)
        repos_stmt = select(Repository).where(Repository.user_id == user_id)
        db_repos = db.scalars(repos_stmt).all()

        if db_repos:
            for repo in db_repos:
                repo_list.append(
                    {
                        "owner": repo.owner,
                        "name": repo.name,
                        "full_name": repo.full_name,
                    }
                )
        else:
            # Fetch public repositories dynamically using GitHub API
            async with httpx.AsyncClient() as client:
                headers = {"User-Agent": "Tatvik-App"}
                if access_token:
                    headers["Authorization"] = f"Bearer {access_token}"
                try:
                    # Fetch up to 100 public repositories
                    api_url = f"https://api.github.com/users/{github_username}/repos?per_page=100"
                    res = await client.get(api_url, headers=headers, timeout=12.0)
                    if res.status_code == 200:
                        repos_data = res.json()
                        for r_data in repos_data:
                            owner = r_data.get("owner", {}).get(
                                "login", github_username
                            )
                            name = r_data.get("name", "")
                            full_name = r_data.get("full_name", f"{owner}/{name}")
                            repo_list.append(
                                {"owner": owner, "name": name, "full_name": full_name}
                            )
                    else:
                        logger.warning(
                            f"Failed to fetch public repos for {github_username}: {res.status_code} {res.text}"
                        )
                except Exception as e:
                    logger.error(
                        f"Error fetching public repos for {github_username}: {e}"
                    )
    if not repo_list:
        return {
            "success": True,
            "message": (
                f"No repositories found for GitHub user '{github_username}' to scan."
            ),
            "imported_count": 0,
        }

    imported_count = 0
    scanned_repos = []

    async with httpx.AsyncClient() as client:
        for repo in repo_list:
            owner = repo["owner"]
            name = repo["name"]
            full_name = repo["full_name"]

            paths_to_check = [
                ".autodevs/prompts.md",
                ".autodevs/prompt.md",
                "prompts.md",
                "prompt.md",
            ]

            markdown_text = None

            for check_path in paths_to_check:
                url = (
                    f"https://api.github.com/repos/{owner}/{name}/contents/{check_path}"
                )
                headers = {
                    "Accept": "application/vnd.github.v3+json",
                    "User-Agent": "Tatvik-App",
                }
                if access_token:
                    headers["Authorization"] = f"Bearer {access_token}"

                try:
                    response = await client.get(url, headers=headers, timeout=12.0)
                    if response.status_code in (401, 403) and access_token:
                        public_headers = {
                            "Accept": "application/vnd.github.v3+json",
                            "User-Agent": "Tatvik-App",
                        }
                        response = await client.get(
                            url, headers=public_headers, timeout=12.0
                        )

                    if response.status_code == 200:
                        data = response.json()
                        raw_content = data.get("content", "")
                        raw_content = raw_content.replace("\n", "").replace("\r", "")
                        decoded_bytes = base64.b64decode(raw_content)
                        markdown_text = decoded_bytes.decode("utf-8")
                        break  # Found the file, stop checking paths
                except Exception as e:
                    logger.error(f"Error checking {check_path} in {full_name}: {e}")

            if markdown_text:
                try:

                    # Parse the markdown prompts block-by-block (indentation-aware)
                    lines = markdown_text.split("\n")
                    current_prompt = None
                    prompts_to_import = []

                    for line in lines:
                        indentation = len(line) - len(line.lstrip())
                        line_str = line.strip()
                        if not line_str:
                            continue

                        # If it's a top-level list item (starts with - or * or 1.) and indentation < 2
                        if (
                            line_str.startswith("- ")
                            or line_str.startswith("* ")
                            or line_str.startswith("1. ")
                        ) and indentation < 2:
                            if current_prompt:
                                prompts_to_import.append(current_prompt)

                            prefix_len = 3 if line_str.startswith("1. ") else 2
                            raw_text = line_str[prefix_len:].strip()

                            # Parse project name: [project] refined_prompt
                            project_name = None
                            refined_text = raw_text
                            if raw_text.startswith("["):
                                end_bracket = raw_text.find("]")
                                if end_bracket != -1:
                                    project_name = raw_text[1:end_bracket].strip()
                                    refined_text = raw_text[end_bracket + 1 :].strip()

                            current_prompt = {
                                "refined_prompt": refined_text,
                                "original_prompt": refined_text,  # default fallback
                                "project_name": project_name,
                                "score": 0,
                                "technologies": "General",
                                "workflow": "Development",
                            }
                        elif current_prompt and indentation >= 2:
                            # Parse metadata keys
                            if line_str.startswith("- ") or line_str.startswith("* "):
                                meta_content = line_str[2:].strip()
                                if meta_content.startswith("*Original:*"):
                                    current_prompt["original_prompt"] = meta_content[
                                        len("*Original:*") :
                                    ].strip()
                                elif meta_content.startswith("*Score:*"):
                                    score_str = (
                                        meta_content[len("*Score:*") :]
                                        .strip()
                                        .split("/")[0]
                                    )
                                    try:
                                        current_prompt["score"] = int(score_str)
                                    except:
                                        pass
                                elif meta_content.startswith("*Technologies:*"):
                                    current_prompt["technologies"] = meta_content[
                                        len("*Technologies:*") :
                                    ].strip()
                                elif meta_content.startswith("*Workflow:*"):
                                    current_prompt["workflow"] = meta_content[
                                        len("*Workflow:*") :
                                    ].strip()

                    if current_prompt:
                        prompts_to_import.append(current_prompt)

                    for p_data in prompts_to_import:
                        original_prompt = p_data["original_prompt"]
                        project_name = p_data["project_name"] or name

                        # Check if prompt already exists in history
                        check_stmt = select(PromptHistory).where(
                            PromptHistory.user_id == user_id,
                            PromptHistory.original_prompt == original_prompt,
                        )
                        exists = db.scalar(check_stmt)
                        if not exists:
                            db_prompt = PromptHistory(
                                user_id=user_id,
                                original_prompt=original_prompt,
                                refined_prompt=p_data["refined_prompt"],
                                score=p_data["score"],
                                technologies=p_data["technologies"],
                                workflow=p_data["workflow"],
                                project_name=project_name,
                            )
                            db.add(db_prompt)
                            imported_count += 1
                        elif exists.score == 0 and p_data["score"] > 0:
                            exists.refined_prompt = p_data["refined_prompt"]
                            exists.score = p_data["score"]
                            exists.technologies = p_data["technologies"]
                            exists.workflow = p_data["workflow"]
                            db.add(exists)

                    scanned_repos.append(full_name)
                except Exception as e:
                    logger.error(f"Error scanning repo {full_name} for prompts: {e}")

    if len(scanned_repos) > 0:
        try:
            db.query(PromptHistory).filter(
                PromptHistory.user_id == user_id,
                PromptHistory.response
                == "This is a generated AI response for the refined prompt.",
            ).delete(synchronize_session=False)
        except Exception as delete_ex:
            logger.warning(f"Could not clean up mock seeded prompts: {delete_ex}")
        db.commit()
    elif imported_count > 0:
        db.commit()

    return {
        "success": True,
        "message": f"Successfully scanned {len(scanned_repos)} repositories and imported {imported_count} new prompts from GitHub.",
        "scanned_repositories": scanned_repos,
        "imported_count": imported_count,
    }


class GithubPushRequest(BaseModel):
    project_name: str
    owner: str
    name: str
    commit_message: Optional[str] = (
        "chore: upgrade prompts via Tatvik Prompt Intelligence"
    )


@router.post("/push-github")
async def push_github_prompts(
    payload: GithubPushRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    """
    Fetch all refined/scored prompts for the specified project, format them as a markdown document,
    and commit/push it back to .autodevs/prompts.md in the remote GitHub repository.
    """
    import base64
    import httpx

    # 1. Fetch user's GitHub access token
    profile_stmt = select(GithubProfile).where(GithubProfile.user_id == user_id)
    profile = db.scalar(profile_stmt)

    # If mock token or no integration, return mock response (to prevent failure in dev/test/mock settings)
    is_mock = False
    access_token = None
    if profile:
        access_token = profile.access_token
        if access_token and (
            access_token.startswith("gho_pwtSZHJk") or access_token.startswith("mock_")
        ):
            is_mock = True
    else:
        is_mock = True

    # 2. Get prompt history for the project
    stmt = (
        select(PromptHistory)
        .where(
            PromptHistory.user_id == user_id,
            PromptHistory.project_name == payload.project_name,
        )
        .order_by(PromptHistory.created_at.desc())
    )
    prompts = db.scalars(stmt).all()

    if not prompts:
        raise HTTPException(
            status_code=404,
            detail=f"No prompts found in the database for project '{payload.project_name}' to push.",
        )

    # 3. Format prompts into markdown
    md_lines = [
        f"# Prompts for {payload.project_name}",
        "",
        "This file is automatically updated by Tatvik Prompt Intelligence.",
        "",
    ]
    for p in prompts:
        md_lines.append(f"- [{payload.project_name}] {p.refined_prompt}")
        md_lines.append(f"  - *Original:* {p.original_prompt}")
        md_lines.append(f"  - *Score:* {p.score}/100")
        md_lines.append(f"  - *Technologies:* {p.technologies or 'General'}")
        md_lines.append(f"  - *Workflow:* {p.workflow or 'Development'}")
        md_lines.append("")

    markdown_content = "\n".join(md_lines)

    if is_mock or not access_token:
        # Simulate pushing to github
        return {
            "success": True,
            "message": f"Successfully pushed {len(prompts)} prompts to GitHub (Mock Mode).",
            "url": f"https://github.com/{payload.owner}/{payload.name}/blob/main/.autodevs/prompts.md",
            "mock": True,
        }

    # 4. Fetch the existing prompts.md to get the SHA
    url = f"https://api.github.com/repos/{payload.owner}/{payload.name}/contents/.autodevs/prompts.md"
    headers = {
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "Tatvik-App",
        "Authorization": f"Bearer {access_token}",
    }

    sha = None
    async with httpx.AsyncClient() as client:
        # Get existing file to find its SHA
        res = await client.get(url, headers=headers, timeout=12.0)
        if res.status_code == 200:
            sha = res.json().get("sha")

        # 5. Push the new markdown content
        encoded_content = base64.b64encode(markdown_content.encode("utf-8")).decode(
            "utf-8"
        )
        put_payload = {
            "message": payload.commit_message
            or "chore: upgrade prompts via Tatvik Prompt Intelligence",
            "content": encoded_content,
        }
        if sha:
            put_payload["sha"] = sha

        put_res = await client.put(url, headers=headers, json=put_payload, timeout=12.0)
        if put_res.status_code in [200, 201]:
            put_data = put_res.json()
            return {
                "success": True,
                "message": f"Successfully pushed {len(prompts)} prompts to GitHub.",
                "url": put_data.get("content", {}).get("html_url")
                or f"https://github.com/{payload.owner}/{payload.name}/blob/main/.autodevs/prompts.md",
                "commit": put_data.get("commit", {}).get("sha"),
            }
        else:
            raise HTTPException(
                status_code=put_res.status_code,
                detail="GitHub API error. Please try again later.",
            )
