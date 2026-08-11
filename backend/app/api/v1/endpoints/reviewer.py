import logging
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.api.deps import get_optional_user_id
from app.core.config import settings
from app.services.openclaw_service import OpenClawService
from app.services.cognee_service import CogneeService

logger = logging.getLogger(__name__)
router = APIRouter()
_openclaw_service = OpenClawService()
_cognee_service = CogneeService()


class ReviewRequest(BaseModel):
    repo_url: str
    branch: str | None = None


class ReviewResponse(BaseModel):
    success: bool
    security_score: int
    performance_score: int
    architecture_score: int
    maintainability_score: int
    summary: str
    issues: list[str]


@router.post("/", response_model=ReviewResponse)
async def run_continuous_code_review(
    request: ReviewRequest,
    user_id: str | None = Depends(get_optional_user_id),
):
    """
    Continuous Code Reviewer: Analyzes architecture, security, performance, accessibility.
    Dispatches task to OpenClaw to analyze the repo, then uses Gemini to generate standard scores.
    """
    if not (
        settings.gemini_api_key or settings.groq_api_key or settings.openrouter_api_key
    ):
        raise HTTPException(status_code=500, detail="LLM API key not configured")

    # 1. Ask OpenClaw to clone and analyze the codebase structure
    logger.info(f"Dispatching Code Review for {request.repo_url}")
    branch_text = (
        f" branch {request.branch}" if request.branch else " on its default branch"
    )
    claw_task = f"Clone {request.repo_url}{branch_text}. Analyze the architecture, dependencies, and code quality. Do not modify files. Just print a summary of the tech stack, major files, and obvious code smells."

    kwargs = {
        "repo_url": request.repo_url,
        "task_description": claw_task,
    }
    if request.branch:
        kwargs["branch_name"] = request.branch

    claw_result = await _openclaw_service.execute_task(**kwargs)

    # Extract the raw output from OpenClaw (the file tree / analysis)
    raw_analysis = str(claw_result.get("message", claw_result))

    if claw_result.get("success") is False:
        error_msg = str(claw_result.get("error", raw_analysis))
        if (
            "readtimeout" in error_msg.lower()
            or "timeout" in error_msg.lower()
            or "timed out" in error_msg.lower()
        ):
            return ReviewResponse(
                success=False,
                security_score=0,
                performance_score=0,
                architecture_score=0,
                maintainability_score=0,
                summary="The analysis is taking longer than expected. OpenClaw is continuing the review securely in the background.",
                issues=["Timeout waiting for analysis to finish synchronously."],
            )

    if "<!DOCTYPE html>" in raw_analysis or claw_result.get("success") is False:
        logger.warning(f"OpenClaw returned an error or HTML page: {raw_analysis[:200]}")
        raise HTTPException(
            status_code=503,
            detail="The OpenClaw AI environment is currently booting up from sleep mode on Hugging Face. Please wait 1-2 minutes and try your request again.",
        )

    # 2. Use Gemini/Llama to generate the exact scores and detailed review
    system_prompt = (
        "You are the AutoDevs Continuous Code Reviewer (Principal Staff Engineer level).\n"
        "You will receive a raw analysis of a repository.\n"
        "You must generate a strict JSON response containing:\n"
        "{\n"
        '  "security_score": int (0-100),\n'
        '  "performance_score": int (0-100),\n'
        '  "architecture_score": int (0-100),\n'
        '  "maintainability_score": int (0-100),\n'
        '  "summary": "String explaining the overall health",\n'
        '  "issues": ["List of string issues/recommendations"]\n'
        "}\n"
        "Do not output anything outside of the JSON block."
    )

    prompt_text = (
        f"{system_prompt}\n\nReview this repository analysis:\n\n{raw_analysis}"
    )

    try:
        from app.api.v1.endpoints.advanced import call_ai_json

        review_data = await call_ai_json(prompt_text, task_type="heavy")
        if review_data:
            # Persist review results into Cognee Cloud for growth tracking
            if user_id:
                await _cognee_service.remember_review_result(
                    user_id, request.repo_url, review_data
                )
                # Store individual issues as mistakes for the Smart Mentor
                for issue in review_data.get("issues", [])[:5]:
                    category = "general"
                    lower = issue.lower()
                    if "security" in lower:
                        category = "security"
                    elif "performance" in lower or "slow" in lower:
                        category = "performance"
                    elif "architect" in lower or "structure" in lower:
                        category = "architecture"
                    elif "maintain" in lower or "readab" in lower:
                        category = "maintainability"
                    await _cognee_service.remember_mistake(user_id, issue, category)

            return ReviewResponse(
                success=True,
                security_score=review_data.get("security_score", 0),
                performance_score=review_data.get("performance_score", 0),
                architecture_score=review_data.get("architecture_score", 0),
                maintainability_score=review_data.get("maintainability_score", 0),
                summary=review_data.get("summary", "Analysis complete."),
                issues=review_data.get("issues", []),
            )
        else:
            raise HTTPException(
                status_code=500, detail="LLM failed to output valid JSON for review."
            )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Code Reviewer Exception: {e}")
        raise HTTPException(
            status_code=500, detail="An error occurred during code review."
        )
