import logging
import httpx
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.api.deps import get_current_user_id, get_db
from app.core.config import settings
from app.models.entities import Repository, TechNews, GithubProfile
from app.services.cognee_service import CogneeService
from app.services.openclaw_service import OpenClawService
from app.tatvik.graph.cognee_client import cognee_client
import re
from app.services.github_agent_service import GithubAgentService

router = APIRouter()
logger = logging.getLogger(__name__)

# Singleton service instances
_cognee_service = CogneeService()
_openclaw_service = OpenClawService()


class HistoryMessage(BaseModel):
    role: str  # 'user' or 'assistant'
    content: str


class MentorMessageRequest(BaseModel):
    message: str
    resume_context: str | None = None
    history: list[HistoryMessage] = []


async def search_github_repositories(
    topic_query: str, access_token: str = None
) -> list:
    """
    Search GitHub repositories for a given topic or keyword, sorted by stars.
    """
    q = topic_query.lower().strip()
    if "cybersecurity" in q or "cyber security" in q:
        search_q = "topic:cybersecurity"
    elif "data science" in q or "datascience" in q:
        search_q = "topic:data-science"
    elif "machine learning" in q or "machinelearning" in q:
        search_q = "topic:machine-learning"
    elif "artificial intelligence" in q or " ai " in q or q.startswith("ai "):
        search_q = "topic:artificial-intelligence"
    elif "web dev" in q or "web development" in q:
        search_q = "topic:web-development"
    elif "flutter" in q or "mobile dev" in q:
        search_q = "topic:flutter"
    else:
        search_q = q

    url = f"https://api.github.com/search/repositories?q={search_q}&sort=stars&order=desc&per_page=5"
    headers = {
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "Tatvik-App",
    }
    if access_token:
        headers["Authorization"] = f"token {access_token}"

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, headers=headers, timeout=12.0)
            if response.status_code == 200:
                items = response.json().get("items", [])
                return [
                    {
                        "name": item.get("name"),
                        "full_name": item.get("full_name"),
                        "description": item.get("description")
                        or "No description provided.",
                        "stars": item.get("stargazers_count", 0),
                        "html_url": item.get("html_url"),
                        "language": item.get("language"),
                    }
                    for item in items
                ]
        except Exception as e:
            import logging

            logging.getLogger(__name__).error(f"Error calling GitHub Search API: {e}")
    return []


@router.post("/chat")
async def mentor_chat(
    payload: MentorMessageRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    try:
        # 1. Fetch user repositories from db to build contextual developer profile
        stmt = select(Repository).where(Repository.user_id == user_id)
        repos = db.scalars(stmt).all()
        repo_list_str = (
            ", ".join([r.full_name for r in repos])
            if repos
            else "No repositories synced yet"
        )

        # 2. Get user's github profile to see if we have access token
        profile_stmt = select(GithubProfile).where(GithubProfile.user_id == user_id)
        profile = db.scalar(profile_stmt)
        access_token = profile.access_token if profile else None

        # 2a. Fetch long-term memory context from Cognee for this user
        cognee_memory_context = ""
        try:
            memory = await _cognee_service.get_developer_profile(user_id)
            if memory and "results" in memory and memory["results"]:
                cognee_memory_context = (
                    "\nLong-term Developer Memory (from previous sessions):\n"
                    + str(memory["results"])[:800]  # cap at 800 chars
                    + "\n"
                )
        except Exception as e:
            logger.warning(f"Could not fetch Cognee memory for user {user_id}: {e}")

        # 3. Detect if they are asking for top repositories
        msg_lower = payload.message.lower()
        github_context = ""
        if any(
            k in msg_lower
            for k in [
                "top repo",
                "best repo",
                "popular repo",
                "excelling repo",
                "top github",
                "best github",
                "popular github",
                "excelling github",
            ]
        ):
            # Determine the topic
            topic = "data-science"
            if "cybersecurity" in msg_lower or "cyber security" in msg_lower:
                topic = "cybersecurity"
            elif "machine learning" in msg_lower or "machinelearning" in msg_lower:
                topic = "machine-learning"
            elif "ai" in msg_lower or "artificial intelligence" in msg_lower:
                topic = "artificial-intelligence"
            elif "web dev" in msg_lower or "web development" in msg_lower:
                topic = "web-development"
            elif "mobile" in msg_lower or "flutter" in msg_lower:
                topic = "flutter"

            # Query Github Search API
            search_results = await search_github_repositories(topic, access_token)
            if search_results:
                github_context = (
                    "\nReal-time Top Repositories in "
                    + topic.replace("-", " ")
                    + " from GitHub:\n"
                )
                for r in search_results:
                    github_context += f"- {r['full_name']} ({r['stars']} stars): {r['description']} (Link: {r['html_url']})\n"
            else:
                github_context = (
                    f"\nNo real-time repositories found for topic {topic}.\n"
                )

        # 4. Fetch the latest scanned tech news
        news_stmt = select(TechNews).order_by(TechNews.scanned_at.desc()).limit(8)
        news_records = db.scalars(news_stmt).all()
        news_context = ""
        if news_records:
            news_context = "\nReal-time 24/7 Scanned Tech News Headlines:\n"
            for n in news_records:
                news_context += f"- {n.title} (Link: {n.link})\n"
        else:
            news_context = "\nNo real-time tech news scanned yet.\n"

        # 5. Build the system prompt with strict concise plaintext rules
        system_prompt = (
            "You are Tatvik, a highly specialized developer growth coach. Your role is strictly to analyze "
            "the user's GitHub activity, repositories, commits, skill gaps, and uploaded resume, and provide career roadmaps, "
            "resume feedback, and development mentoring. You MUST NOT answer any general knowledge, coding help unrelated to their "
            "profile, or non-mentoring questions. If the user asks anything outside of Tatvik guidance, "
            "politely decline and steer them back to their career development.\n\n"
            "CRITICAL RESPONSE STYLE GUIDELINES:\n"
            "- Keep your answers extremely short, concise, and punchy (maximum of 2-3 sentences, or a quick list).\n"
            "- Do NOT use markdown bolding (e.g. never use '**').\n"
            "- Do NOT use markdown headers (e.g. never use '#', '##', or '###').\n"
            "- Write in simple, clean, plain text that fits easily in a small chat bubble. Keep it engaging so the user doesn't get bored.\n"
            "- Write in simple, clean, plain text that fits easily in a small chat bubble. Keep it engaging so the user doesn't get bored.\n"
            "- Present links as raw clean URLs (e.g. https://github.com/...), not markdown format.\n"
            "- **AUTONOMOUS EXECUTION:** If you need to test code, check system state, or run a terminal command, output EXACTLY the command inside this XML tag: `<run_terminal>your command here</run_terminal>`. The system will intercept this, run it securely in OpenClaw sandbox, and feed the output back to you.\n"
            "- **BROWSER TESTING:** If you need to navigate to a URL to test UI or check a web app, output exactly: `<open_browser>https://url-here</open_browser>`.\n\n"
            "You have access to real-time information below. When the user asks about trending repos, tech news, "
            "what's happening in tech, or roadmaps, you MUST use the real data provided below to answer them. DO NOT "
            "make up mock names or links. Provide the real repository names, stars, descriptions, and hyperlinks.\n\n"
            f"Context - Synced User Repositories: {repo_list_str}\n"
        )

        if payload.resume_context:
            system_prompt += f"\nContext - User's Uploaded Resume (use this to help tailor suggestions, discuss their background, or answer job/resume questions):\n{payload.resume_context}\n"

        system_prompt += (
            f"{cognee_memory_context}"
            f"{github_context}"
            f"{news_context}\n"
            "Always recommend actionable learning steps based on these real-time tech trends and repositories."
        )

        # 5b. Detect agentic action keywords to dispatch to GithubAgentService or OpenClaw
        github_action_keywords = [
            "execute",
            "create pr",
            "open pr",
            "make a pr",
            "raise a pr",
            "raise pr",
            "create pull request",
            "fix this bug",
            "implement this",
            "build this feature",
            "write the code",
            "edit the file",
        ]
        terminal_keywords = [
            "run command",
            "deploy",
            "run terminal",
        ]

        openclaw_result = None
        target_repo = None

        # 1. Try to match repo by full name or short name from user's synced repos list
        if repos:
            # First pass: check if any full name (e.g. owner/name) is explicitly in user message
            for r in repos:
                if r.full_name.lower() in msg_lower:
                    target_repo = r.full_name
                    break

            # Second pass: check for standalone name matches (e.g. "tatvik" or "autodev")
            if not target_repo:
                import re

                for r in repos:
                    name_lower = r.name.lower()
                    if re.search(rf"\b{re.escape(name_lower)}\b", msg_lower):
                        target_repo = r.full_name
                        break

        # 2. If not found in synced repos, try to parse from the user message (URLs or owner/repo format)
        if not target_repo:
            import re

            # Match GitHub URL: e.g. github.com/owner/repo
            github_url_match = re.search(
                r"github\.com/([a-zA-Z0-9_.-]+)/([a-zA-Z0-9_.-]+)",
                payload.message,
                re.IGNORECASE,
            )
            if github_url_match:
                owner_part = github_url_match.group(1)
                repo_part = github_url_match.group(2)
                # Clean trailing chars like punctuation or slash without polynomial backtracking
                repo_part = re.split(r"[.,;/?)]", repo_part, maxsplit=1)[0]
                target_repo = f"{owner_part}/{repo_part}"
            else:
                # Match owner/repo pattern: e.g. HEETMEHTA18/tatvik
                owner_repo_match = re.search(
                    r"\b([a-zA-Z0-9_.-]+)/([a-zA-Z0-9_.-]+)\b", payload.message
                )
                if owner_repo_match:
                    owner_part = owner_repo_match.group(1)
                    repo_part = owner_repo_match.group(2)
                    # Exclude common false positives like "api/v1" or "endpoints/mentor"
                    false_positives = {
                        "api",
                        "endpoints",
                        "v1",
                        "v2",
                        "app",
                        "src",
                        "lib",
                        "http",
                        "https",
                    }
                    if (
                        owner_part.lower() not in false_positives
                        and repo_part.lower() not in false_positives
                    ):
                        target_repo = f"{owner_part}/{repo_part}"

        # 3. Fallback to the first repository if none was explicitly targeted but repositories exist
        if not target_repo and repos:
            target_repo = repos[0].full_name

        if target_repo:
            if any(k in msg_lower for k in github_action_keywords):
                try:
                    # Use real GitHub Agent for repository modifications
                    github_agent = GithubAgentService(
                        github_token=access_token
                        or getattr(settings, "github_client_secret", "")
                    )
                    logger.info(f"Dispatching GitHub Agent task for repo {target_repo}")
                    openclaw_result = await github_agent.execute_task_and_pr(
                        repo_full_name=target_repo, task=payload.message
                    )
                except Exception as e:
                    logger.warning(f"GitHub Agent dispatch failed: {e}")

            elif any(k in msg_lower for k in terminal_keywords):
                try:
                    # Use OpenClaw for isolated terminal execution
                    logger.info(
                        f"Dispatching OpenClaw terminal task for user {user_id}"
                    )
                    openclaw_result = await _openclaw_service.run_terminal_command(
                        command=payload.message
                    )
                except Exception as e:
                    logger.warning(f"OpenClaw terminal dispatch failed: {e}")

        # 6. Build the conversation history turns for the LLM
        # Sanitise roles to strictly 'user' or 'assistant' to prevent injection
        safe_history = [
            {
                "role": ("user" if h.role == "user" else "assistant"),
                "content": h.content,
            }
            for h in payload.history[-20:]  # cap at 20 prior messages
        ]

        def clean_response(text: str) -> str:
            # Strip bold symbols and header symbols
            cleaned = (
                text.replace("**", "")
                .replace("###", "")
                .replace("##", "")
                .replace("#", "")
            )
            # Replace common markdown list markers with clean dashes if needed
            return cleaned.strip()

        # 7. Agentic Loop - Call AI API (up to 3 iterations for ReAct)
        final_reply = ""
        if openclaw_result:
            # Fast path: bypass LLM if we already executed a task to avoid Render 100s timeout
            if openclaw_result.get("pull_request_url"):
                final_reply = f"I have executed the task! You can view the Pull Request here: {openclaw_result['pull_request_url']}"
            elif openclaw_result.get("output"):
                final_reply = (
                    f"Command executed successfully. Check the terminal output."
                )
            else:
                final_reply = "Task execution completed."

        if _openclaw_service.enabled or settings.nvidia_api_key:
            import re

            if _openclaw_service.enabled:
                url = f"{_openclaw_service.api_url}/v1/chat/completions"
                headers = _openclaw_service.headers
                model_name = "openclaw"
            else:
                url = "https://integrate.api.nvidia.com/v1/chat/completions"
                headers = {
                    "Authorization": f"Bearer {settings.nvidia_api_key}",
                    "Content-Type": "application/json",
                }
                model_name = "meta/llama-3.3-70b-instruct"

            # Initialize loop variables
            max_iterations = 3
            current_iteration = 0
            agent_messages = [
                {"role": "system", "content": system_prompt},
                *safe_history,
                {"role": "user", "content": payload.message},
            ]

            import time

            start_time = time.time()
            async with httpx.AsyncClient() as client:
                try:
                    if final_reply:
                        current_iteration = max_iterations

                    while current_iteration < max_iterations:
                        if time.time() - start_time > 70:
                            logger.warning(
                                "Agentic loop approaching 100s Render timeout. Breaking early."
                            )
                            final_reply = locals().get(
                                "reply",
                                "Task is taking too long to finish. OpenClaw is still processing in the background.",
                            )
                            break

                        response = await client.post(
                            url,
                            json={
                                "model": model_name,
                                "messages": agent_messages,
                            },
                            headers=headers,
                            timeout=60.0,
                        )

                        if response.status_code != 200:
                            logger.error(
                                f"Chat API error (status {response.status_code}): {response.text}"
                            )
                            break

                        data = response.json()
                        reply = data["choices"][0]["message"]["content"]

                        # Intercept autonomous tool execution tags
                        terminal_match = re.search(
                            r"<run_terminal>(.*?)</run_terminal>", reply, re.DOTALL
                        )
                        browser_match = re.search(
                            r"<open_browser>(.*?)</open_browser>", reply, re.DOTALL
                        )

                        if terminal_match:
                            cmd = terminal_match.group(1).strip()
                            logger.info(
                                f"Agentic loop: Intercepted <run_terminal> '{cmd}'"
                            )
                            action_res = await _openclaw_service.run_terminal_command(
                                command=cmd
                            )
                            output = action_res.get("output", str(action_res))
                            if "ReadTimeout" in output or "Timeout" in output:
                                output = "Timeout waiting for response. The command is likely still executing securely in the background. Please conclude the current task or assume it will finish shortly."
                            # Append the AI's generation, then the tool output
                            agent_messages.append(
                                {"role": "assistant", "content": reply}
                            )
                            agent_messages.append(
                                {
                                    "role": "user",
                                    "content": f"System Output for `{cmd}`:\n{output}\nNow continue fulfilling my request.",
                                }
                            )
                            current_iteration += 1
                            openclaw_result = (
                                action_res  # Save to show user what happened
                            )
                            continue

                        elif browser_match:
                            url_to_open = browser_match.group(1).strip()
                            logger.info(
                                f"Agentic loop: Intercepted <open_browser> '{url_to_open}'"
                            )
                            action_res = await _openclaw_service.execute_task(
                                repo_url="",
                                task_description=f"Open browser and test {url_to_open}",
                            )
                            output = str(action_res.get("message", action_res))
                            agent_messages.append(
                                {"role": "assistant", "content": reply}
                            )
                            agent_messages.append(
                                {
                                    "role": "user",
                                    "content": f"Browser Output for `{url_to_open}`:\n{output}\nNow continue fulfilling my request.",
                                }
                            )
                            current_iteration += 1
                            openclaw_result = action_res
                            continue

                        # No actionable tags found, break out of loop
                        final_reply = reply
                        break

                    # After loop finishes, save long-term memory
                    try:
                        # Original profile update
                        await _cognee_service.add_developer_profile(
                            user_id,
                            {
                                "last_message": payload.message,
                                "repos": repo_list_str,
                                "provider": "nvidia",
                            },
                        )

                        # 🚀 New TATVIK Feature: Per-Project Codebase Memory Mindmaps
                        # If the prompt or AI output contains codebase insights, map it to the repo project
                        # Find potential repo links or use the primary selected repo
                        import re

                        repo_matches = re.findall(
                            r"github\.com/([\w.-]+/[\w.-]+)", payload.message
                        )
                        primary_repo = (
                            repo_matches[0] if repo_matches else "general_mindmap"
                        )

                        # Clean up the name for the graph
                        project_name = primary_repo.replace("/", "_").replace(".", "_")

                        if (
                            openclaw_result
                            or "scan" in payload.message.lower()
                            or "explore" in payload.message.lower()
                        ):
                            # We have actionable insights to save into the mindmap
                            insight_data = {
                                "prompt": payload.message,
                                "ai_summary": final_reply,
                                "openclaw_tasks": openclaw_result,
                            }

                            # Create a mock item to hold the memory ID
                            class MockItem:
                                id = f"mem_{int(datetime.now().timestamp())}"

                            await cognee_client.build_knowledge_graph_from_item(
                                repo_name=project_name,
                                item=MockItem(),
                                enriched_data=insight_data,
                            )

                    except Exception as e:
                        logger.error(f"Failed to sync codebase memory to Cognee: {e}")

                    response_data = {
                        "user_id": user_id,
                        "assistant_message": clean_response(
                            final_reply
                            or "I was unable to complete the agentic workflow."
                        ),
                    }
                    if openclaw_result:
                        response_data["openclaw_task"] = openclaw_result
                    return response_data

                except Exception as e:
                    import logging

                    logging.getLogger(__name__).error(f"Error calling NVIDIA: {e}")

        api_key = settings.gemini_api_key
        if api_key and not final_reply:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key={api_key}"
            async with httpx.AsyncClient() as client:
                try:
                    # Gemini uses 'user'/'model' roles and a flat contents list.
                    # Prepend the system prompt to the very first user turn.
                    gemini_contents = []
                    for idx, h in enumerate(safe_history):
                        text_content = h["content"]
                        if idx == 0 and h["role"] == "user":
                            text_content = f"{system_prompt}\n\n{text_content}"
                        gemini_contents.append(
                            {
                                "role": "user" if h["role"] == "user" else "model",
                                "parts": [{"text": text_content}],
                            }
                        )

                    # Append the current user message
                    # If there's no history, inject system prompt into this turn
                    if not safe_history:
                        current_text = (
                            f"{system_prompt}\n\nUser message: {payload.message}"
                        )
                    else:
                        current_text = payload.message
                    gemini_contents.append(
                        {"role": "user", "parts": [{"text": current_text}]}
                    )

                    response = await client.post(
                        url,
                        json={"contents": gemini_contents},
                        headers={"Content-Type": "application/json"},
                        timeout=30.0,
                    )
                    if response.status_code == 200:
                        data = response.json()
                        try:
                            reply = data["candidates"][0]["content"]["parts"][0]["text"]
                            # Save this exchange to Cognee long-term memory
                            try:
                                await _cognee_service.add_developer_profile(
                                    user_id,
                                    {
                                        "last_message": payload.message,
                                        "repos": repo_list_str,
                                        "provider": "gemini",
                                    },
                                )
                            except Exception:
                                pass
                            response_data = {
                                "user_id": user_id,
                                "assistant_message": clean_response(reply),
                            }
                            if openclaw_result:
                                response_data["openclaw_task"] = openclaw_result
                            return response_data
                        except (KeyError, IndexError):
                            import logging

                            logging.getLogger(__name__).error(
                                "Malformed Gemini response"
                            )
                    else:
                        import logging

                        logging.getLogger(__name__).error(
                            f"Gemini API error: {response.text}"
                        )
                except Exception as e:
                    import logging

                    logging.getLogger(__name__).error(f"Error calling Gemini: {e}")

        # Ultimate fallback if no keys exist or if both API calls failed
        return {
            "user_id": user_id,
            "assistant_message": f"[Stub Mode] Synced repos: {repo_list_str}. You asked: {payload.message}",
        }
    except Exception as e:
        logger.error(f"Error in mentor chat endpoint: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An internal error occurred during the mentor session.",
        )
