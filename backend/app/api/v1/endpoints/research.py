import subprocess
import json
import logging
import re
import os
import httpx
import yt_dlp
from typing import List, Optional
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status, Request
from pydantic import BaseModel, HttpUrl
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.api.deps import get_current_user_id, get_optional_user_id, get_db
from app.core.config import settings
from app.models.entities import ResearchSession, ResearchResult, WeeklyDigest, Roadmap
import redis

logger = logging.getLogger(__name__)

router = APIRouter()

# Redis Setup
try:
    redis_client = redis.from_url(settings.redis_url, decode_responses=True)
except Exception:
    redis_client = None


def get_cache(key: str) -> dict | None:
    if not redis_client:
        return None
    try:
        data = redis_client.get(key)
        if data:
            return json.loads(data)
    except Exception:
        pass
    return None


def set_cache(key: str, value: dict, expire: int = 86400) -> None:
    if not redis_client:
        return
    try:
        redis_client.set(key, json.dumps(value), ex=expire)
    except Exception:
        pass


def check_rate_limit(
    request: Request, user_id: str, limit: int = 20, window: int = 3600
):
    if not redis_client:
        return

    # Secure real client IP parsing (proxy-safe to prevent user-rate limit triggering for all users behind a proxy)
    x_forwarded_for = request.headers.get("x-forwarded-for")
    if x_forwarded_for:
        client_ip = x_forwarded_for.split(",")[0].strip()
    else:
        client_ip = request.headers.get("x-real-ip", "").strip() or (
            request.client.host if request.client else "unknown"
        )

    user_key = f"rate_limit:user:{user_id}"
    ip_key = f"rate_limit:ip:{client_ip}"

    try:
        user_count = redis_client.get(user_key)
        if user_count and int(user_count) >= limit:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Rate limit exceeded. Please try again later.",
            )

        # IP limit acts as a fallback to prevent brute-force attacks / botnets
        ip_limit = limit * 2
        ip_count = redis_client.get(ip_key)
        if ip_count and int(ip_count) >= ip_limit:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Rate limit exceeded. Please try again later.",
            )

        # Pipe multi increments safely
        pipe = redis_client.pipeline()
        pipe.incr(user_key)
        if not user_count:
            pipe.expire(user_key, window)

        pipe.incr(ip_key)
        if not ip_count:
            pipe.expire(ip_key, window)

        pipe.execute()
    except HTTPException:
        raise
    except Exception:
        # Fallback to allow request if Redis fails (prevents complete outage if Redis is down)
        pass


# Gemini AI Orchestrator Helper
async def call_gemini(system_prompt: str, user_prompt: str) -> str:
    api_key = settings.gemini_api_key
    if not api_key:
        return "[Gemini API Key missing] Stub summary response."

    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key}"
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                url,
                json={
                    "contents": [
                        {
                            "parts": [
                                {"text": f"{system_prompt}\nUser Input:\n{user_prompt}"}
                            ]
                        }
                    ]
                },
                headers={"Content-Type": "application/json"},
                timeout=30.0,
            )
            if response.status_code == 200:
                data = response.json()
                try:
                    return data["candidates"][0]["content"]["parts"][0]["text"]
                except (KeyError, IndexError):
                    return "Error: Malformed Gemini API response."
            else:
                logger.error(f"Gemini API returned status {response.status_code}")
                return "Error: AI service returned an error. Please try again later."
        except Exception as e:
            logger.exception("Gemini API call failed")
            return "Error: AI service unavailable. Please try again later."


GITHUB_API_HEADERS = {
    "Accept": "application/vnd.github.v3+json",
    "User-Agent": "DevMentor-App",
}


async def _search_github_repos(query: str, limit: int = 5) -> list[dict]:
    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://api.github.com/search/repositories",
            params={"q": query, "sort": "stars", "order": "desc", "per_page": limit},
            headers=GITHUB_API_HEADERS,
            timeout=15.0,
        )
        if response.status_code != 200:
            raise Exception(f"GitHub API returned status {response.status_code}")
        data = response.json()
        return [
            {
                "fullName": item["full_name"],
                "description": item.get("description", ""),
                "stargazersCount": item["stargazers_count"],
                "url": item["html_url"],
            }
            for item in data.get("items", [])
        ]


def _sanitize_video_id(video_id: str) -> str:
    safe = re.sub(r"[^a-zA-Z0-9_-]", "", video_id)
    if not safe:
        raise ValueError("Invalid video ID after sanitization")
    return safe


# Schemas
class GitHubResearchRequest(BaseModel):
    url: Optional[str] = None
    query: Optional[str] = None
    limit: Optional[int] = 5


class YouTubeResearchRequest(BaseModel):
    url: str


class RedditResearchRequest(BaseModel):
    query: str


class RSSResearchRequest(BaseModel):
    url: str


class ProjectAnalysisRequest(BaseModel):
    project_idea: str


class LearningPathRequest(BaseModel):
    role: str
    target_technologies: Optional[List[str]] = []


@router.post("/github")
async def research_github(
    payload: GitHubResearchRequest,
    request: Request,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    check_rate_limit(request, user_id)

    if not payload.url and not payload.query:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either 'url' or 'query' must be provided.",
        )

    # Input validation and sanitization
    if payload.query:
        if len(payload.query) > 100:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Query parameter is too long (maximum 100 characters).",
            )
        if not re.match(r"^[a-zA-Z0-9\s\-_.,#]+$", payload.query):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Query contains invalid or unsafe characters.",
            )

    if payload.url:
        if len(payload.url) > 500:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail="URL is too long."
            )
        if not re.match(
            r"^https?://(www\.)?github\.com/[a-zA-Z0-9\-_.]+/[a-zA-Z0-9\-_.]+(/.*)?$",
            payload.url,
        ):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or unsafe GitHub URL.",
            )

    cache_key = f"research:github:{payload.url or payload.query}"
    cached = get_cache(cache_key)
    if cached:
        return cached

    # Save Session
    session_obj = ResearchSession(user_id=user_id, query=payload.url or payload.query)
    db.add(session_obj)
    db.commit()
    db.refresh(session_obj)

    if payload.url:
        jina_url = f"https://r.jina.ai/{payload.url}"
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(jina_url, timeout=20.0)
                if response.status_code != 200:
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail="Failed to scrape GitHub repository from upstream reader.",
                    )
                scraped_content = response.text
            except Exception:
                logger.exception("Jina Reader request failed")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Failed to fetch repository data. Please try again later.",
                )

        system_prompt = (
            "You are an expert AI Repository Coach. Analyze the provided repository markdown scraped from GitHub. "
            "Identify the architecture, primary technology stack, suggest 3 improvements/refactoring tips, "
            "outline a step-by-step learning roadmap for a junior developer to understand this codebase, "
            "and rate its complexity (1 to 10). Provide a well-structured response."
        )
        ai_summary = await call_gemini(system_prompt, scraped_content)

        result_obj = ResearchResult(
            session_id=session_obj.id,
            platform="github",
            raw_data=scraped_content[:5000],
            summary=ai_summary,
        )
        db.add(result_obj)
        db.commit()

        res_data = {
            "session_id": session_obj.id,
            "platform": "github",
            "url": payload.url,
            "summary": ai_summary,
        }
        set_cache(cache_key, res_data)
        return res_data

    else:
        try:
            repos = await _search_github_repos(
                payload.query, min(payload.limit or 5, 20)
            )
        except Exception:
            logger.exception("GitHub search failed")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to search GitHub repositories. Please try again later.",
            )

        system_prompt = (
            f"You are an expert AI Tech Mentor. Below is a JSON list of matching GitHub repositories for the query '{payload.query}'. "
            "Analyze and summarize the top trends, recommend which templates are best for development, "
            "and suggest how they can help a developer build their project."
        )
        ai_summary = await call_gemini(system_prompt, json.dumps(repos, indent=2))

        result_obj = ResearchResult(
            session_id=session_obj.id,
            platform="github",
            raw_data=json.dumps(repos),
            summary=ai_summary,
        )
        db.add(result_obj)
        db.commit()

        res_data = {
            "session_id": session_obj.id,
            "platform": "github",
            "query": payload.query,
            "results": repos,
            "summary": ai_summary,
        }
        set_cache(cache_key, res_data)
        return res_data


@router.post("/youtube")
async def research_youtube(
    payload: YouTubeResearchRequest,
    request: Request,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    check_rate_limit(request, user_id)

    if len(payload.url) > 500:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="URL is too long."
        )
    # Validate YouTube URL format
    if not re.match(r"^https?://(www\.)?(youtube\.com|youtu\.be)/.+$", payload.url):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid YouTube URL."
        )

    video_id_match = re.search(
        r"(?:v=|\/embed\/|\/11\/|\/v\/|https:\/\/youtu\.be\/)([^&\n?#]+)", payload.url
    )
    if not video_id_match:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid YouTube video ID."
        )
    raw_video_id = video_id_match.group(1)
    video_id = _sanitize_video_id(raw_video_id)

    cache_key = f"research:youtube:{video_id}"
    cached = get_cache(cache_key)
    if cached:
        return cached

    # Save Session
    session_obj = ResearchSession(user_id=user_id, query=payload.url)
    db.add(session_obj)
    db.commit()
    db.refresh(session_obj)

    safe_video_id = os.path.basename(video_id)
    safe_url = f"https://www.youtube.com/watch?v={safe_video_id}"
    subtitle_path = os.path.abspath(f"/tmp/yt_{safe_video_id}")
    if not subtitle_path.startswith(os.path.abspath("/tmp")):
        raise ValueError("Path traversal detected")

    raw_subtitles = ""
    try:
        ydl_opts = {
            "writesubtitles": True,
            "writeautomaticsub": True,
            "subtitleslangs": ["en"],
            "skip_download": True,
            "outtmpl": subtitle_path,
            "quiet": True,
        }
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([safe_url])

        vtt_file = os.path.abspath(f"{subtitle_path}.en.vtt")
        if not vtt_file.startswith(os.path.abspath("/tmp")):
            raise ValueError("Path traversal detected")
        if os.path.exists(vtt_file):
            try:
                with open(vtt_file, "r") as f:
                    vtt_content = f.read()

                lines = vtt_content.splitlines()
                cleaned_lines = []
                last_line = ""
                for line in lines:
                    line = line.strip()
                    if (
                        not line
                        or line.startswith("WEBVTT")
                        or line.startswith("Kind:")
                        or line.startswith("Language:")
                        or "-->" in line
                    ):
                        continue
                    line = re.sub(r"<[^>]+>", "", line).strip()
                    if not line:
                        continue
                    if line == last_line:
                        continue
                    cleaned_lines.append(line)
                    last_line = line
                raw_subtitles = " ".join(cleaned_lines)

                os.remove(vtt_file)
            except Exception:
                pass
    except Exception:
        logger.exception("yt-dlp subtitle download failed")

    video_info_str = ""
    try:
        ydl_opts = {"quiet": True}
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(safe_url, download=False)
            if info:
                video_info_str = f"Title: {info.get('title')}\nDescription:\n{info.get('description')}"
    except Exception:
        logger.exception("yt-dlp info fetch failed")

    if not raw_subtitles and not video_info_str:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve YouTube video transcripts or description.",
        )

    user_prompt = f"Video Info:\n{video_info_str}\n\nTranscript / Subtitles:\n{raw_subtitles or '[No subtitles available]'}"

    system_prompt = (
        "You are an expert AI Tutorial Assistant. Analyze the provided YouTube video description and transcripts. "
        "Summarize the main core concepts taught in the video, outline step-by-step instructions, and extract "
        "any code snippets, resources, or links mentioned. Keep the summary highly educational and developer-centric."
    )
    ai_summary = await call_gemini(system_prompt, user_prompt)

    result_obj = ResearchResult(
        session_id=session_obj.id,
        platform="youtube",
        raw_data=user_prompt[:5000],
        summary=ai_summary,
    )
    db.add(result_obj)
    db.commit()

    res_data = {
        "session_id": session_obj.id,
        "platform": "youtube",
        "url": payload.url,
        "summary": ai_summary,
    }
    set_cache(cache_key, res_data)
    return res_data


@router.post("/reddit")
async def research_reddit(
    payload: RedditResearchRequest,
    request: Request,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    check_rate_limit(request, user_id)

    if len(payload.query) > 100:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Query parameter is too long (maximum 100 characters).",
        )
    if not re.match(r"^[a-zA-Z0-9\s\-_.,#]+$", payload.query):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Query contains invalid or unsafe characters.",
        )

    cache_key = f"research:reddit:{payload.query}"
    cached = get_cache(cache_key)
    if cached:
        return cached

    session_obj = ResearchSession(user_id=user_id, query=payload.query)
    db.add(session_obj)
    db.commit()
    db.refresh(session_obj)

    ddg_url = f"https://html.duckduckgo.com/html/?q=site:reddit.com+{payload.query}"
    jina_url = f"https://r.jina.ai/{ddg_url}"

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(jina_url, timeout=20.0)
            if response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="Failed to search Reddit discussions from upstream reader.",
                )
            scraped_content = response.text
        except Exception:
            logger.exception("Reddit Jina Reader request failed")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to search Reddit discussions. Please try again later.",
            )

    system_prompt = (
        f"You are a developer community sentiment analyzer. Below is a search result from Reddit about '{payload.query}'. "
        "Summarize the general developer consensus, list pros and cons discussed by the community, "
        "and mention any specific tips or alternatives suggested in the threads. Be concise and objective."
    )
    ai_summary = await call_gemini(system_prompt, scraped_content)

    result_obj = ResearchResult(
        session_id=session_obj.id,
        platform="reddit",
        raw_data=scraped_content[:5000],
        summary=ai_summary,
    )
    db.add(result_obj)
    db.commit()

    res_data = {
        "session_id": session_obj.id,
        "platform": "reddit",
        "query": payload.query,
        "summary": ai_summary,
    }
    set_cache(cache_key, res_data)
    return res_data


@router.post("/rss")
async def research_rss(
    payload: RSSResearchRequest,
    request: Request,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    check_rate_limit(request, user_id)

    if len(payload.url) > 500:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="URL is too long."
        )
    if not re.match(r"^https?://.+$", payload.url):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid RSS URL format."
        )

    cache_key = f"research:rss:{payload.url}"
    cached = get_cache(cache_key)
    if cached:
        return cached

    session_obj = ResearchSession(user_id=user_id, query=payload.url)
    db.add(session_obj)
    db.commit()
    db.refresh(session_obj)

    import feedparser

    try:
        feed = feedparser.parse(payload.url)
        if not feed.entries:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No entries found in RSS feed.",
            )
    except Exception:
        logger.exception("RSS feed parsing failed")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to parse RSS feed. Please check the URL and try again.",
        )

    entries_list = []
    for entry in feed.entries[:10]:
        entries_list.append(
            {
                "title": entry.get("title"),
                "link": entry.get("link"),
                "published": entry.get("published"),
                "summary": entry.get("summary", "")[:300],
            }
        )

    system_prompt = (
        "You are an expert AI Newsletter and Tech Scan Assistant. Analyze the provided tech blog RSS feed entries. "
        "Create a concise, bulleted digest highlighting the most important technical releases, tutorials, or updates "
        "and how they are useful to developers."
    )
    ai_summary = await call_gemini(system_prompt, json.dumps(entries_list, indent=2))

    result_obj = ResearchResult(
        session_id=session_obj.id,
        platform="rss",
        raw_data=json.dumps(entries_list),
        summary=ai_summary,
    )
    db.add(result_obj)
    db.commit()

    res_data = {
        "session_id": session_obj.id,
        "platform": "rss",
        "url": payload.url,
        "summary": ai_summary,
    }
    set_cache(cache_key, res_data)
    return res_data


@router.post("/project-analysis")
async def research_project_analysis(
    payload: ProjectAnalysisRequest,
    request: Request,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    check_rate_limit(request, user_id)

    if len(payload.project_idea) > 250:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Project idea is too long."
        )
    if not re.match(r"^[a-zA-Z0-9\s\-_.,#?!()]+$", payload.project_idea):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Project idea contains invalid or unsafe characters.",
        )

    repos = []
    try:
        repos = await _search_github_repos(payload.project_idea, limit=3)
    except Exception:
        logger.exception("GitHub search in project-analysis failed")

    system_prompt = (
        "You are an expert AI Project Architect. Given a developer's project idea and some matching template repositories, "
        "create a detailed implementation plan. This should include: 1. Optimal tech stack, 2. A checklist of milestones "
        "with concrete tasks for each, 3. Best practices, and 4. Pitfalls to avoid."
    )

    user_prompt = f"Project Idea: {payload.project_idea}\n\nRelated Templates:\n{json.dumps(repos, indent=2)}"
    ai_summary = await call_gemini(system_prompt, user_prompt)

    roadmap_obj = Roadmap(
        user_id=user_id,
        title=f"Project Roadmap: {payload.project_idea[:50]}",
        milestones=ai_summary,
        status="active",
    )
    db.add(roadmap_obj)

    session_obj = ResearchSession(user_id=user_id, query=payload.project_idea)
    db.add(session_obj)
    db.commit()
    db.refresh(session_obj)

    result_obj = ResearchResult(
        session_id=session_obj.id,
        platform="project-analysis",
        raw_data=user_prompt,
        summary=ai_summary,
    )
    db.add(result_obj)
    db.commit()

    return {
        "session_id": session_obj.id,
        "roadmap_id": roadmap_obj.id,
        "roadmap_title": roadmap_obj.title,
        "analysis": ai_summary,
    }


@router.post("/learning-path")
async def research_learning_path(
    payload: LearningPathRequest,
    request: Request,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    check_rate_limit(request, user_id)

    if len(payload.role) > 100:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Role name is too long."
        )
    if not re.match(r"^[a-zA-Z0-9\s\-_.,#]+$", payload.role):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Role name contains invalid or unsafe characters.",
        )
    if payload.target_technologies:
        if len(payload.target_technologies) > 10:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Too many target technologies specified.",
            )
        for tech in payload.target_technologies:
            if len(tech) > 50 or not re.match(r"^[a-zA-Z0-9\s\-_.]+$", tech):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Invalid target technology name: {tech}",
                )

    repos = []
    try:
        query_str = f"{payload.role} roadmap tutorial"
        repos = await _search_github_repos(query_str, limit=3)
    except Exception:
        logger.exception("GitHub search in learning-path failed")

    system_prompt = (
        "You are an expert AI Career Mentor. Generate a detailed, step-by-step learning roadmap "
        f"for the role of '{payload.role}'. Include fundamental concepts, core libraries/tools to learn, "
        "recommended reference projects from GitHub, and milestones. Structure it clearly."
    )

    user_prompt = f"Target Role: {payload.role}\nTarget Technologies: {', '.join(payload.target_technologies)}\nGitHub Reference Repos:\n{json.dumps(repos, indent=2)}"
    ai_summary = await call_gemini(system_prompt, user_prompt)

    session_obj = ResearchSession(
        user_id=user_id, query=f"Learning Path: {payload.role}"
    )
    db.add(session_obj)
    db.commit()
    db.refresh(session_obj)

    result_obj = ResearchResult(
        session_id=session_obj.id,
        platform="learning-path",
        raw_data=user_prompt,
        summary=ai_summary,
    )
    db.add(result_obj)

    roadmap_obj = Roadmap(
        user_id=user_id,
        title=f"Learning Path: {payload.role}",
        milestones=ai_summary,
        status="active",
    )
    db.add(roadmap_obj)
    db.commit()

    return {
        "session_id": session_obj.id,
        "roadmap_id": roadmap_obj.id,
        "roadmap_title": roadmap_obj.title,
        "learning_path": ai_summary,
    }


@router.get("/digest")
async def get_weekly_digest(
    request: Request,
    topic: str = "general",
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    check_rate_limit(request, user_id)

    if len(topic) > 50 or not re.match(r"^[a-zA-Z0-9\-_]+$", topic):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid topic parameter."
        )

    stmt = (
        select(WeeklyDigest)
        .where(WeeklyDigest.topic == topic)
        .order_by(WeeklyDigest.created_at.desc())
    )
    digest = db.scalar(stmt)
    if digest:
        return {
            "topic": topic,
            "digest": digest.digest_text,
            "created_at": digest.created_at,
        }

    rss_url = "https://news.ycombinator.com/rss"
    import feedparser

    try:
        feed = feedparser.parse(rss_url)
        entries = [
            {"title": e.get("title"), "link": e.get("link")} for e in feed.entries[:15]
        ]
    except Exception:
        entries = []

    system_prompt = (
        "You are an AI Tech Journalist. Summarize the latest trending HackerNews stories into a cohesive, "
        "one-paragraph technical update for developers. Focus on tools, libraries, or major architectural events."
    )
    ai_summary = await call_gemini(system_prompt, json.dumps(entries))

    new_digest = WeeklyDigest(topic=topic, digest_text=ai_summary)
    db.add(new_digest)
    db.commit()
    db.refresh(new_digest)

    return {
        "topic": topic,
        "digest": new_digest.digest_text,
        "created_at": new_digest.created_at,
    }


@router.get("/whats-new")
async def get_whats_new(
    request: Request,
    user_id: Optional[str] = Depends(get_optional_user_id),
    db: Session = Depends(get_db),
):
    # Use user_id if authenticated, otherwise fall back to IP for rate limiting
    rate_limit_key = user_id or (
        request.headers.get("x-forwarded-for", "").split(",")[0].strip()
        or (request.client.host if request.client else "guest")
    )
    check_rate_limit(request, rate_limit_key)

    cache_key = "research:whats_new"
    cached = get_cache(cache_key)
    if cached:
        return cached

    # 1. Fetch GitHub trends
    github_items = []
    try:
        import datetime as dt

        date_limit = (dt.date.today() - dt.timedelta(days=7)).isoformat()

        async with httpx.AsyncClient() as client:
            headers = {
                "Accept": "application/vnd.github.v3+json",
                "User-Agent": "DevMentor-App",
            }
            gh_res = await client.get(
                f"https://api.github.com/search/repositories?q=stars:>50+created:>{date_limit}&sort=stars&order=desc",
                headers=headers,
                timeout=10.0,
            )
            if gh_res.status_code == 200:
                data = gh_res.json()
                for item in data.get("items", [])[:5]:
                    github_items.append(
                        {
                            "name": item.get("name", ""),
                            "owner": item.get("owner", {}).get("login", ""),
                            "description": item.get("description", "")
                            or "No description",
                            "stars": item.get("stargazers_count", 0),
                            "url": item.get("html_url", ""),
                        }
                    )
    except Exception as e:
        logger.error(f"Error fetching GitHub trends in whats-new: {e}")

    if not github_items:
        github_items = [
            {
                "name": "fastapi",
                "owner": "tiangolo",
                "description": "FastAPI framework, high performance, easy to learn, fast to code, ready for production",
                "stars": 75000,
                "url": "https://github.com/tiangolo/fastapi",
            },
            {
                "name": "flutter",
                "owner": "flutter",
                "description": "Flutter makes it easy and fast to build beautiful apps for mobile and beyond",
                "stars": 160000,
                "url": "https://github.com/flutter/flutter",
            },
            {
                "name": "transformers",
                "owner": "huggingface",
                "description": "State-of-the-art Machine Learning for PyTorch, TensorFlow, and JAX.",
                "stars": 125000,
                "url": "https://github.com/huggingface/transformers",
            },
        ]

    # 2. Fetch YouTube trends via search feed
    youtube_items = []
    try:
        import xml.etree.ElementTree as ET

        async with httpx.AsyncClient() as client:
            yt_res = await client.get(
                "https://www.youtube.com/feeds/videos.xml?search_query=programming+tutorial",
                timeout=10.0,
            )
            if yt_res.status_code == 200:
                root = ET.fromstring(yt_res.content)
                ns = {"atom": "http://www.w3.org/2005/Atom"}
                for entry in root.findall("atom:entry", ns)[:5]:
                    title_elem = entry.find("atom:title", ns)
                    link_elem = entry.find("atom:link", ns)
                    author_elem = entry.find("atom:author/atom:name", ns)

                    title = title_elem.text if title_elem is not None else ""
                    url = (
                        link_elem.attrib.get("href", "")
                        if link_elem is not None
                        else ""
                    )
                    author = (
                        author_elem.text if author_elem is not None else "Tech Channel"
                    )

                    if title and url:
                        youtube_items.append(
                            {"title": title, "url": url, "channel": author}
                        )
    except Exception as e:
        logger.error(f"Error fetching YouTube trends in whats-new: {e}")

    if not youtube_items:
        youtube_items = [
            {
                "title": "System Design for Beginners",
                "channel": "ByteByteGo",
                "url": "https://youtube.com",
            },
            {
                "title": "Gemini 2.5 Coding Tutorial",
                "channel": "Google Devs",
                "url": "https://youtube.com",
            },
            {
                "title": "FastAPI + PWA Integration Guide",
                "channel": "Devmentor",
                "url": "https://youtube.com",
            },
        ]

    # 3. Call Gemini to create a rich summary and research digest
    system_prompt = (
        "You are an expert technical research agent. Analyze the following list of active GitHub repositories "
        "and YouTube video feeds. Write a professional, high-fidelity developer summary explaining what's new "
        "and trending. Format the output with clear bullet points. Keep it engaging, insightful, and strictly under 250 words."
    )
    user_prompt = f"GitHub repositories:\n{json.dumps(github_items)}\n\nYouTube Videos:\n{json.dumps(youtube_items)}"
    ai_digest = await call_gemini(system_prompt, user_prompt)

    result = {
        "github": github_items,
        "youtube": youtube_items,
        "digest": ai_digest,
        "timestamp": datetime.utcnow().isoformat(),
    }

    set_cache(cache_key, result, 3600)
    return result
