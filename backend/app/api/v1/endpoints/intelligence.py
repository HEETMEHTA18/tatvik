"""
AI Intelligence Hub Endpoints
=============================
Powered by Cognee Cloud (memory) + OpenClaw (agentic execution).

Features:
  1. Smart Mentor (recalls past mistakes before answering)
  2. Auto-Fix PRs (OpenClaw clones, fixes, and opens a PR)
  3. Weekly Developer Growth Report
  4. Voice Code Review (talk-voice plugin)
  5. Codebase Q&A Search ("Where is auth handled?")
  6. Live UI Audit (browser + canvas plugins)
  7. Developer Skill Badges
  8. Smart Repository Onboarding
"""

import logging
import os
import re
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.api.deps import get_current_user_id, get_optional_user_id
from app.core.config import settings
from app.services.cognee_service import CogneeService
from app.services.openclaw_service import OpenClawService
from app.services.pipeline_status import pipeline_tracker, PipelineStepInfo

logger = logging.getLogger(__name__)
router = APIRouter()
_cognee = CogneeService()
_openclaw = OpenClawService()


async def _warmup_openclaw():
    """Pre-warm the OpenClaw HF Space before execution."""
    try:
        await _openclaw.warmup()
    except Exception:
        pass


# ──────────────────────────────────────────────
# REQUEST / RESPONSE MODELS
# ──────────────────────────────────────────────


class SmartMentorRequest(BaseModel):
    question: str
    repo_url: str | None = None


class SmartMentorResponse(BaseModel):
    answer: str
    past_mistakes: list[str]
    personalized: bool


class AutoFixRequest(BaseModel):
    repo_url: str
    issues: list[str]
    branch: str | None = None


class AutoFixResponse(BaseModel):
    success: bool
    message: str
    pull_request_url: str | None = None


class GrowthReportResponse(BaseModel):
    period: str
    skills_improved: list[str]
    recurring_mistakes: list[str]
    average_scores: dict
    recommendations: list[str]
    badge_progress: dict


class VoiceReviewRequest(BaseModel):
    transcript: str
    repo_url: str | None = None


class VoiceReviewResponse(BaseModel):
    success: bool
    review_summary: str
    scores: dict


class VoicePipelineRequest(BaseModel):
    transcript: str
    repo_url: str | None = None
    branch: str | None = None


class VoicePipelineResponse(BaseModel):
    success: bool
    message: str
    prompt_content: str
    pull_request_url: str | None = None


class CodebaseQARequest(BaseModel):
    question: str


class CodebaseQAResponse(BaseModel):
    answer: str
    source: str


class UIAuditRequest(BaseModel):
    target_url: str
    focus_areas: list[str] | None = None


class UIAuditResponse(BaseModel):
    success: bool
    audit_report: str
    issues_found: list[str]


class BadgeResponse(BaseModel):
    badges: list[dict]
    total_reviews: int
    strongest_skill: str
    weakest_skill: str


class OnboardRequest(BaseModel):
    repo_url: str


class OnboardResponse(BaseModel):
    success: bool
    tech_stack: list[str]
    architecture_summary: str
    dependency_risks: list[str]
    suggested_first_issues: list[str]
    readme_summary: str


# ──────────────────────────────────────────────
# 1. SMART MENTOR (Recalls Past Mistakes)
# ──────────────────────────────────────────────


@router.post("/smart-mentor", response_model=SmartMentorResponse)
async def smart_mentor(
    request: SmartMentorRequest,
    user_id: str = Depends(get_current_user_id),
):
    """
    AI Mentor that remembers your past coding mistakes and personalizes
    its advice. Powered by Cognee Cloud knowledge graph.
    """
    # 1. Recall past mistakes from Cognee
    profile = await _cognee.get_developer_profile(user_id)
    past_data = str(profile.get("results", ""))

    past_mistakes = []
    if past_data and len(past_data) > 20:
        past_mistakes = [
            line.strip()
            for line in past_data.split("\\n")
            if "mistake" in line.lower() or "issue" in line.lower()
        ][:5]

    # 2. Build a personalized prompt
    context = ""
    if past_mistakes:
        context = (
            "IMPORTANT CONTEXT: This developer has made these mistakes "
            f"before: {'; '.join(past_mistakes)}. "
            "Reference their past issues in your advice to help them "
            "avoid repeating them.\n\n"
        )

    prompt = (
        "You are Tatvik, a senior AI coding mentor. "
        "You remember the developer's history and give personalized advice.\n\n"
        f"{context}"
        f"Developer's question: {request.question}\n\n"
        "Provide a clear, actionable answer. If relevant, mention their "
        "past mistakes and how to avoid them this time."
    )

    try:
        from app.api.v1.endpoints.advanced import call_ai_json

        result = await call_ai_json(
            prompt
            + '\n\nRespond in JSON: {"answer": "...", "referenced_mistakes": ["..."]}',
            task_type="heavy",
        )
        if result:
            return SmartMentorResponse(
                answer=result.get("answer", "I can help with that!"),
                past_mistakes=result.get("referenced_mistakes", past_mistakes),
                personalized=bool(past_mistakes),
            )
    except Exception as e:
        logger.error(f"Smart mentor error: {e}")

    return SmartMentorResponse(
        answer="I'm here to help! Ask me any coding question.",
        past_mistakes=[],
        personalized=False,
    )


# ──────────────────────────────────────────────
# 2. AUTO-FIX PRs (OpenClaw clones, fixes, PRs)
# ──────────────────────────────────────────────


@router.post("/auto-fix", response_model=AutoFixResponse)
async def auto_fix_pr(
    request: AutoFixRequest,
    user_id: str = Depends(get_current_user_id),
):
    """
    Takes the issues found in a code review and dispatches OpenClaw
    to automatically fix them and open a Pull Request.
    """
    issues_text = "\n".join(f"- {issue}" for issue in request.issues)
    branch = request.branch or "tatvik-auto-fix"

    task = (
        f"Clone {request.repo_url}. Create a new branch called "
        f"'{branch}'. Fix the following issues:\n{issues_text}\n\n"
        f"After fixing, commit the changes and push the branch. "
        f"Then open a Pull Request to the default branch with a clear "
        f"description of what was fixed."
    )

    result = await _openclaw.execute_task(
        repo_url=request.repo_url,
        task_description=task,
        branch_name=branch,
    )

    if result.get("success"):
        # Remember the fix attempt
        await _cognee.remember_review_result(
            user_id,
            request.repo_url,
            {"action": "auto-fix", "issues_fixed": request.issues},
        )
        return AutoFixResponse(
            success=True,
            message=result.get("message", "Auto-fix PR created successfully!"),
            pull_request_url=result.get("pull_request_url"),
        )

    return AutoFixResponse(
        success=False,
        message=result.get("error", "Auto-fix failed. Please try again."),
        pull_request_url=None,
    )


# ──────────────────────────────────────────────
# 3. WEEKLY DEVELOPER GROWTH REPORT
# ──────────────────────────────────────────────


@router.get("/growth-report", response_model=GrowthReportResponse)
async def weekly_growth_report(
    user_id: str = Depends(get_current_user_id),
):
    """
    Generates a comprehensive weekly developer growth report by querying
    all review history, mistakes, and improvements from Cognee Cloud.
    """
    growth_data = await _cognee.get_weekly_growth_data(user_id)
    raw = str(growth_data.get("results", ""))

    prompt = (
        "You are an AI developer coach. Based on this developer's weekly "
        f"activity data, generate a growth report.\n\nData:\n{raw}\n\n"
        "Respond in strict JSON:\n"
        "{\n"
        '  "skills_improved": ["list of skills that got better"],\n'
        '  "recurring_mistakes": ["patterns they keep repeating"],\n'
        '  "average_scores": {"security": N, "performance": N, '
        '"architecture": N, "maintainability": N},\n'
        '  "recommendations": ["actionable next steps"],\n'
        '  "badge_progress": {"Security Champion": "60%", ...}\n'
        "}"
    )

    try:
        from app.api.v1.endpoints.advanced import call_ai_json

        result = await call_ai_json(prompt, task_type="heavy")
        if result:
            return GrowthReportResponse(
                period=f"Week of {datetime.utcnow().strftime('%B %d, %Y')}",
                skills_improved=result.get("skills_improved", []),
                recurring_mistakes=result.get("recurring_mistakes", []),
                average_scores=result.get(
                    "average_scores",
                    {
                        "security": 0,
                        "performance": 0,
                        "architecture": 0,
                        "maintainability": 0,
                    },
                ),
                recommendations=result.get("recommendations", []),
                badge_progress=result.get("badge_progress", {}),
            )
    except Exception as e:
        logger.error(f"Growth report error: {e}")

    return GrowthReportResponse(
        period=f"Week of {datetime.utcnow().strftime('%B %d, %Y')}",
        skills_improved=["Keep reviewing to track progress!"],
        recurring_mistakes=[],
        average_scores={
            "security": 0,
            "performance": 0,
            "architecture": 0,
            "maintainability": 0,
        },
        recommendations=["Run your first code review to start tracking."],
        badge_progress={},
    )


# ──────────────────────────────────────────────
# 4. VOICE CODE REVIEW
# ──────────────────────────────────────────────


@router.post("/voice-review", response_model=VoiceReviewResponse)
async def voice_code_review(
    request: VoiceReviewRequest,
    user_id: str = Depends(get_current_user_id),
):
    """
    Accepts a voice transcript (from speech-to-text) and triggers a
    code review. Uses OpenClaw's talk-voice plugin context.
    """
    repo_url = request.repo_url or "https://github.com/HEETMEHTA18/tatvik"

    # Use OpenClaw to analyze the repo based on the voice command
    task = (
        f"The developer said: '{request.transcript}'. "
        f"Based on this voice command, analyze the repository at {repo_url}. "
        f"Provide a brief code review summary with security, performance, "
        f"architecture, and maintainability scores (0-100 each)."
    )

    result = await _openclaw.execute_task(
        repo_url=repo_url,
        task_description=task,
    )

    raw = str(result.get("message", ""))

    if "<!DOCTYPE html>" in raw or not result.get("success"):
        return VoiceReviewResponse(
            success=False,
            review_summary="OpenClaw is still waking up. Please try again in a minute.",
            scores={},
        )

    # Parse with Gemini
    prompt = (
        f"Parse this review into JSON:\n{raw}\n\n"
        'Output: {{"summary": "...", "scores": {{"security": N, '
        '"performance": N, "architecture": N, "maintainability": N}}}}'
    )

    try:
        from app.api.v1.endpoints.advanced import call_ai_json

        parsed = await call_ai_json(prompt, task_type="heavy")
        if parsed:
            return VoiceReviewResponse(
                success=True,
                review_summary=parsed.get("summary", raw[:500]),
                scores=parsed.get("scores", {}),
            )
    except Exception as e:
        logger.error(f"Voice review parse error: {e}")

    return VoiceReviewResponse(
        success=True,
        review_summary=raw[:500],
        scores={},
    )


@router.post("/voice-pipeline", response_model=VoicePipelineResponse)
async def voice_pipeline(
    request: VoicePipelineRequest,
    user_id: str = Depends(get_current_user_id),
):
    """
    Voice Pipeline:
    1. AI 1 (Prompt Writer) parses the transcript and generates the contents of a structured prompt.md.
    2. Writes prompt.md locally to .autodev/prompt.md and .autodevs/prompt.md.
    3. If a repo is targeted, writes it to GitHub via GithubAgentService.
    4. AI 2 (Project Builder) reads prompt.md and implements the project.
    """
    logger.info(
        f"Received Voice Pipeline request: '{request.transcript}' for repo '{request.repo_url}'"
    )
    repo_url = request.repo_url or "https://github.com/HEETMEHTA18/tatvik"
    branch = request.branch or "tatvik-voice-pipeline"

    pipeline_tracker.start_planning(request.transcript)
    pipeline_tracker.set_phase(
        "planning", "AI Prompt Writer generating specification..."
    )

    # Step 1: AI 1 generates the prompt.md content
    prompt_gen_instruction = (
        "You are an AI Architect. Based on the developer's voice instruction: "
        f"'{request.transcript}'\n\n"
        "Generate a structured specification for a developer agent in Markdown format. "
        "The output should begin with '# Specification: [Feature Name]' and must detail:\n"
        "1. ## Context / Goal\n"
        "2. ## Files to Create/Modify\n"
        "3. ## Step-by-Step Implementation Guide\n"
        "4. ## Verification & Testing Instructions\n\n"
        "Return ONLY the raw markdown content. Do not wrap in markdown code fences, do not write preambles. "
        "Just the raw markdown."
    )

    try:
        from app.api.v1.endpoints.advanced import call_ai

        prompt_content = await call_ai(prompt_gen_instruction, task_type="heavy")
        if not prompt_content or len(prompt_content.strip()) < 20:
            prompt_content = (
                f"# Specification: Custom Feature\n\n"
                f"## Context / Goal\n"
                f"Implement the following voice instruction: {request.transcript}\n\n"
                f"## Files to Create/Modify\n"
                f"Modify files as required by the instruction.\n\n"
                f"## Step-by-Step Implementation Guide\n"
                f"Locate files, implement logic, and write tests.\n"
            )
    except Exception as e:
        logger.error(f"Failed to generate prompt.md content: {e}")
        prompt_content = (
            f"# Specification: Custom Feature\n\n"
            f"## Context / Goal\n"
            f"Implement the following voice instruction: {request.transcript}\n\n"
            f"## Files to Create/Modify\n"
            f"Modify files as required by the instruction.\n\n"
            f"## Step-by-Step Implementation Guide\n"
            f"Locate files, implement logic, and write tests.\n"
        )

    # Step 2: Write prompt.md locally
    local_paths = [
        "/home/heet18/Projects/devmentor/.autodev/prompt.md",
        "/home/heet18/Projects/devmentor/.autodevs/prompt.md",
    ]
    for p in local_paths:
        try:
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w", encoding="utf-8") as f:
                f.write(prompt_content)
            logger.info(f"Successfully wrote local prompt file to {p}")
        except Exception as e:
            logger.warning(f"Could not write local prompt file to {p}: {e}")

    pipeline_tracker.add_step(
        PipelineStepInfo(
            step="Write prompt.md", status="done", details="Specification generated"
        )
    )
    pipeline_tracker.set_phase(
        "executing_openclaw", "OpenClaw implementing the specification..."
    )
    pipeline_tracker.add_step(
        PipelineStepInfo(
            step="Execute on repository",
            status="running",
            tool_id="openclaw",
            capability="execute_task",
        )
    )

    # Step 3: Run the second AI (OpenClaw / GithubAgentService) on the generated prompt.md
    pr_url = None
    agent_message = "Local prompt written."

    task = (
        f"Read and execute the instructions specified in '.autodev/prompt.md' (or '.autodevs/prompt.md') "
        f"in the repository. Implement all feature logic, verify compilation, "
        f"commit the code, and open a Pull Request."
    )

    try:
        from app.services.github_agent_service import GithubAgentService

        github_agent = GithubAgentService(github_token=settings.github_token)
        if github_agent.enabled:
            owner, repo_name = github_agent._parse_owner_repo(repo_url)
            if owner and repo_name:
                logger.info(
                    f"Writing prompt.md to remote branch '{branch}' via GitHub API"
                )
                await github_agent._create_branch(owner, repo_name, branch)
                await github_agent._put_file(
                    owner=owner,
                    repo=repo_name,
                    path=".autodev/prompt.md",
                    content=prompt_content,
                    message="chore: add voice pipeline prompt.md",
                    sha=None,
                    branch=branch,
                )
                await github_agent._put_file(
                    owner=owner,
                    repo=repo_name,
                    path=".autodevs/prompt.md",
                    content=prompt_content,
                    message="chore: add voice pipeline prompts.md",
                    sha=None,
                    branch=branch,
                )

                result = await _openclaw.execute_task(
                    repo_url=repo_url, task_description=task, branch_name=branch
                )
                if result.get("success"):
                    pr_url = result.get("pull_request_url")
                    agent_message = result.get(
                        "message", "Voice pipeline executed successfully."
                    )
                else:
                    agent_message = result.get(
                        "error", "OpenClaw failed to execute voice pipeline."
                    )
            else:
                result = await _openclaw.execute_task(
                    repo_url=repo_url, task_description=task, branch_name=branch
                )
        else:
            result = await _openclaw.execute_task(
                repo_url=repo_url, task_description=task, branch_name=branch
            )
            if result.get("success"):
                pr_url = result.get("pull_request_url")
                agent_message = result.get(
                    "message", "Voice pipeline executed successfully."
                )
            else:
                agent_message = result.get(
                    "error", "OpenClaw failed to execute voice pipeline."
                )
        ok = result.get("success", False)
        pipeline_tracker.update_step(
            1,
            "done" if ok else "failed",
            (
                f"PR: {result.get('pull_request_url', 'N/A')}"
                if ok
                else result.get("error", "")
            ),
        )
        pipeline_tracker.finish(ok)
    except Exception as e:
        logger.error(f"Error executing Voice Pipeline task: {e}")
        agent_message = f"Error: {e}"
        pipeline_tracker.update_step(1, "failed", str(e))
        pipeline_tracker.finish(False)

    return VoicePipelineResponse(
        success=True,
        message=agent_message,
        prompt_content=prompt_content,
        pull_request_url=pr_url,
    )


# ──────────────────────────────────────────────
# 5. CODEBASE Q&A SEARCH
# ──────────────────────────────────────────────


@router.post("/codebase-qa", response_model=CodebaseQAResponse)
async def codebase_qa(
    request: CodebaseQARequest,
    user_id: str = Depends(get_current_user_id),
):
    """
    Natural language Q&A over an indexed codebase. Ask things like:
    'Where is authentication handled?' or 'What database does this use?'
    """
    answer = await _cognee.ask_codebase(user_id, request.question)

    return CodebaseQAResponse(
        answer=answer,
        source="Cognee Cloud Knowledge Graph",
    )


# ──────────────────────────────────────────────
# 6. LIVE UI AUDIT
# ──────────────────────────────────────────────


@router.post("/ui-audit", response_model=UIAuditResponse)
async def live_ui_audit(
    request: UIAuditRequest,
    user_id: str = Depends(get_current_user_id),
):
    """
    Uses OpenClaw's browser + canvas plugins to navigate a live URL,
    take screenshots, and generate a comprehensive UI audit report.
    """
    focus = ", ".join(request.focus_areas or ["accessibility", "responsiveness", "UX"])

    instructions = (
        f"Navigate to {request.target_url}. Take screenshots of every major page. "
        f"Evaluate the UI for: {focus}. "
        f"Check for broken links, missing alt text, color contrast issues, "
        f"and mobile responsiveness. Provide a detailed audit report."
    )

    result = await _openclaw.test_ui_with_browser(
        target_url=request.target_url,
        ui_instructions=instructions,
    )

    if result.get("success"):
        raw = result.get("message", "")

        # Parse into structured format
        prompt = (
            f"Parse this UI audit into JSON:\n{raw}\n\n"
            'Output: {{"audit_report": "...", "issues_found": ["..."]}}'
        )
        try:
            from app.api.v1.endpoints.advanced import call_ai_json

            parsed = await call_ai_json(prompt, task_type="heavy")
            if parsed:
                return UIAuditResponse(
                    success=True,
                    audit_report=parsed.get("audit_report", raw[:1000]),
                    issues_found=parsed.get("issues_found", []),
                )
        except Exception as e:
            logger.error(f"UI audit parse error: {e}")

        return UIAuditResponse(
            success=True,
            audit_report=raw[:1000],
            issues_found=[],
        )

    return UIAuditResponse(
        success=False,
        audit_report=result.get("error", "OpenClaw browser plugin is unavailable."),
        issues_found=[],
    )


# ──────────────────────────────────────────────
# 7. DEVELOPER SKILL BADGES
# ──────────────────────────────────────────────

BADGE_DEFINITIONS = [
    {
        "name": "Security Champion",
        "icon": "🛡️",
        "description": "3+ reviews with security score above 80",
        "category": "security",
        "threshold": 80,
        "required_count": 3,
    },
    {
        "name": "Performance Guru",
        "icon": "⚡",
        "description": "3+ reviews with performance score above 80",
        "category": "performance",
        "threshold": 80,
        "required_count": 3,
    },
    {
        "name": "Architecture Master",
        "icon": "🧱",
        "description": "3+ reviews with architecture score above 80",
        "category": "architecture",
        "threshold": 80,
        "required_count": 3,
    },
    {
        "name": "Clean Coder",
        "icon": "✨",
        "description": "3+ reviews with maintainability score above 80",
        "category": "maintainability",
        "threshold": 80,
        "required_count": 3,
    },
    {
        "name": "Code Reviewer Pro",
        "icon": "🔍",
        "description": "Completed 10+ code reviews",
        "category": "total",
        "threshold": 0,
        "required_count": 10,
    },
    {
        "name": "Perfectionist",
        "icon": "💎",
        "description": "1+ review with all scores above 90",
        "category": "all_above_90",
        "threshold": 90,
        "required_count": 1,
    },
    {
        "name": "Rising Star",
        "icon": "🌟",
        "description": "Complete your first code review",
        "category": "total",
        "threshold": 0,
        "required_count": 1,
    },
]


@router.get("/badges", response_model=BadgeResponse)
async def get_developer_badges(
    user_id: str = Depends(get_current_user_id),
):
    """
    Returns skill badges earned based on historical code review performance
    stored in Cognee Cloud.
    """
    badge_data = await _cognee.get_skill_badges(user_id)
    raw = str(badge_data.get("results", ""))

    # Parse the raw data to determine badge eligibility
    prompt = (
        f"Analyze this developer's review history:\n{raw}\n\n"
        "Output strict JSON:\n"
        "{\n"
        '  "total_reviews": N,\n'
        '  "avg_security": N,\n'
        '  "avg_performance": N,\n'
        '  "avg_architecture": N,\n'
        '  "avg_maintainability": N,\n'
        '  "high_security_count": N,\n'
        '  "high_performance_count": N,\n'
        '  "high_architecture_count": N,\n'
        '  "high_maintainability_count": N,\n'
        '  "perfect_reviews": N\n'
        "}\n"
        "Where high_X_count = reviews where that score was above 80, "
        "and perfect_reviews = reviews where ALL scores were above 90."
    )

    stats = {
        "total_reviews": 0,
        "avg_security": 0,
        "avg_performance": 0,
        "avg_architecture": 0,
        "avg_maintainability": 0,
        "high_security_count": 0,
        "high_performance_count": 0,
        "high_architecture_count": 0,
        "high_maintainability_count": 0,
        "perfect_reviews": 0,
    }

    try:
        from app.api.v1.endpoints.advanced import call_ai_json

        parsed = await call_ai_json(prompt, task_type="heavy")
        if parsed:
            stats = parsed
    except Exception as e:
        logger.error(f"Badge parse error: {e}")

    total = stats.get("total_reviews", 0)
    earned_badges = []

    for badge in BADGE_DEFINITIONS:
        earned = False
        cat = badge["category"]

        if cat == "total":
            earned = total >= badge["required_count"]
        elif cat == "security":
            earned = stats.get("high_security_count", 0) >= badge["required_count"]
        elif cat == "performance":
            earned = stats.get("high_performance_count", 0) >= badge["required_count"]
        elif cat == "architecture":
            earned = stats.get("high_architecture_count", 0) >= badge["required_count"]
        elif cat == "maintainability":
            earned = (
                stats.get("high_maintainability_count", 0) >= badge["required_count"]
            )
        elif cat == "all_above_90":
            earned = stats.get("perfect_reviews", 0) >= badge["required_count"]

        earned_badges.append(
            {
                "name": badge["name"],
                "icon": badge["icon"],
                "description": badge["description"],
                "earned": earned,
            }
        )

    # Determine strongest / weakest skill
    skill_scores = {
        "security": stats.get("avg_security", 0),
        "performance": stats.get("avg_performance", 0),
        "architecture": stats.get("avg_architecture", 0),
        "maintainability": stats.get("avg_maintainability", 0),
    }
    strongest = max(skill_scores, key=skill_scores.get) if total else "N/A"
    weakest = min(skill_scores, key=skill_scores.get) if total else "N/A"

    return BadgeResponse(
        badges=earned_badges,
        total_reviews=total,
        strongest_skill=strongest,
        weakest_skill=weakest,
    )


# ──────────────────────────────────────────────
# 8. SMART REPOSITORY ONBOARDING
# ──────────────────────────────────────────────


@router.post("/onboard-repo", response_model=OnboardResponse)
async def smart_onboard_repository(
    request: OnboardRequest,
    user_id: str = Depends(get_current_user_id),
):
    """
    When a user adds a new repository, OpenClaw clones it, analyzes the
    full architecture, and Cognee indexes the codebase for future Q&A.
    Returns a comprehensive onboarding summary.
    """
    # 1. Ask OpenClaw to deeply analyze the repo
    task = (
        f"Clone {request.repo_url} on its default branch. "
        f"Analyze and provide:\n"
        f"1. Complete tech stack (languages, frameworks, databases)\n"
        f"2. Architecture summary (monolith/microservices, key patterns)\n"
        f"3. Dependency risk assessment (outdated, vulnerable packages)\n"
        f"4. Suggested first issues for a new contributor\n"
        f"5. README summary\n"
        f"Do NOT modify any files."
    )

    result = await _openclaw.execute_task(
        repo_url=request.repo_url,
        task_description=task,
    )

    raw = str(result.get("message", ""))

    if "<!DOCTYPE html>" in raw or not result.get("success"):
        raise HTTPException(
            status_code=503,
            detail="OpenClaw is still booting. Please try again in 1-2 minutes.",
        )

    # 2. Index the raw analysis into Cognee for future Q&A
    await _cognee.index_repository(
        user_id=user_id,
        repo_name=request.repo_url.split("/")[-1],
        codebase_files=[{"path": "onboarding_analysis.md", "content": raw}],
    )

    # 3. Parse with Gemini
    prompt = (
        f"Parse this repository analysis into JSON:\n{raw}\n\n"
        "Output:\n"
        "{\n"
        '  "tech_stack": ["Python", "FastAPI", ...],\n'
        '  "architecture_summary": "...",\n'
        '  "dependency_risks": ["risk1", ...],\n'
        '  "suggested_first_issues": ["issue1", ...],\n'
        '  "readme_summary": "..."\n'
        "}"
    )

    try:
        from app.api.v1.endpoints.advanced import call_ai_json

        parsed = await call_ai_json(prompt, task_type="heavy")
        if parsed:
            return OnboardResponse(
                success=True,
                tech_stack=parsed.get("tech_stack", []),
                architecture_summary=parsed.get(
                    "architecture_summary", "Analysis complete."
                ),
                dependency_risks=parsed.get("dependency_risks", []),
                suggested_first_issues=parsed.get("suggested_first_issues", []),
                readme_summary=parsed.get("readme_summary", ""),
            )
    except Exception as e:
        logger.error(f"Onboard parse error: {e}")

    return OnboardResponse(
        success=True,
        tech_stack=["Unable to parse"],
        architecture_summary=raw[:500],
        dependency_risks=[],
        suggested_first_issues=[],
        readme_summary="",
    )
