import logging
import json
import httpx
import xml.etree.ElementTree as ET
import asyncio
from typing import List, Dict, Any, Optional
from datetime import datetime

from sqlalchemy.orm import Session
from sqlalchemy import select
from app.models.entities import PulseItem
from app.core.config import settings

logger = logging.getLogger(__name__)

# Priorities: 1) RSS, 2) Official API, 3) Crawler


class PulseEngine:
    def __init__(self, db: Session):
        self.db = db
        # Track simulated budgets
        self.rate_limits = {
            "github": {"remaining": 5000, "reset": 3600},
            "gemini": {"remaining": 1500, "reset": 86400},
        }

    async def fetch_rss(self, url: str) -> List[Dict[str, Any]]:
        """Priority 1: Official RSS Feed"""
        items = []
        async with httpx.AsyncClient() as client:
            try:
                resp = await client.get(url, timeout=15.0)
                if resp.status_code == 200:
                    root = ET.fromstring(resp.content)
                    for item in root.findall(".//item")[
                        : settings.pulse_max_items_per_feed
                    ]:
                        title = item.findtext("title")
                        link = item.findtext("link")
                        desc = item.findtext("description")
                        pub_date = item.findtext("pubDate")
                        if title and link:
                            items.append(
                                {
                                    "title": title.strip(),
                                    "url": link.strip(),
                                    "description": desc.strip() if desc else "",
                                    "source": "RSS",
                                    "published_at": pub_date,
                                }
                            )
            except Exception as e:
                logger.error(f"RSS Fetch Failed {url}: {e}")
        return items

    async def fetch_github_api(self, endpoint: str) -> List[Dict[str, Any]]:
        """Priority 2: Official Public API"""
        if self.rate_limits["github"]["remaining"] < 100:
            logger.warning("GitHub API quota low. Falling back to RSS/Crawling.")
            return []  # Fallback

        items = []
        async with httpx.AsyncClient() as client:
            try:
                headers = {"Accept": "application/vnd.github.v3+json"}
                resp = await client.get(
                    f"https://api.github.com{endpoint}", headers=headers, timeout=15.0
                )
                if resp.status_code == 200:
                    data = resp.json()
                    self.rate_limits["github"]["remaining"] = int(
                        resp.headers.get("x-ratelimit-remaining", 5000)
                    )
                    # parse trending/releases... (mocked loop)
                    for repo in data.get("items", [])[
                        : settings.pulse_max_items_per_feed
                    ]:
                        items.append(
                            {
                                "title": repo.get("full_name"),
                                "url": repo.get("html_url"),
                                "description": repo.get("description", ""),
                                "source": "GitHub API",
                                "language": repo.get("language"),
                            }
                        )
            except Exception as e:
                logger.error(f"GitHub API Fetch Failed: {e}")
        return items

    async def ai_enrichment(self, title: str, description: str) -> Dict[str, Any]:
        """AI Enricher using Gemini for huge payloads to extract schema metrics, with Groq and OpenRouter fallbacks"""
        system_prompt = (
            "You are Tatvik AI. Analyze this tech content. Extract JSON: "
            '{"summary": "3 lines max", "beginner_explanation": "...", "advanced_explanation": "...", '
            '"tags": ["list", "of", "tags"], "sentiment": "positive/neutral/negative", '
            '"related_technologies": ["React", "Node"]}'
        )

        user_prompt = f"Title: {title}\nDescription: {description[:2000]}"

        # 1. Try Gemini
        if settings.gemini_api_key:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={settings.gemini_api_key}"
            max_retries = 3
            backoff_factor = 4.0  # seconds

            async with httpx.AsyncClient() as client:
                for attempt in range(max_retries):
                    try:
                        resp = await client.post(
                            url,
                            json={
                                "contents": [
                                    {
                                        "parts": [
                                            {
                                                "text": f"{system_prompt}\n\n{user_prompt}"
                                            }
                                        ]
                                    }
                                ]
                            },
                            timeout=20.0,
                        )
                        if resp.status_code == 200:
                            txt = resp.json()["candidates"][0]["content"]["parts"][0][
                                "text"
                            ]
                            # Extract JSON from Markdown
                            start = txt.find("{")
                            end = txt.rfind("}") + 1
                            if start != -1 and end != -1:
                                return json.loads(txt[start:end])
                            break
                        elif resp.status_code == 429:
                            wait_time = backoff_factor * (2**attempt)
                            logger.warning(
                                f"Gemini API rate limit hit (429). Retrying in {wait_time:.1f}s... (Attempt {attempt + 1}/{max_retries})"
                            )
                            await asyncio.sleep(wait_time)
                        else:
                            logger.error(
                                f"Gemini API failed with status code {resp.status_code}: {resp.text}"
                            )
                            break
                    except Exception as e:
                        logger.error(
                            f"Gemini AI Enrichment Failed on attempt {attempt + 1}: {e}"
                        )
                        if attempt < max_retries - 1:
                            await asyncio.sleep(backoff_factor * (2**attempt))
                        else:
                            break

        # 2. Try Groq Fallback
        if settings.groq_api_key:
            logger.info("Falling back to Groq for AI Enrichment...")
            url = "https://api.groq.com/openai/v1/chat/completions"
            headers = {
                "Authorization": f"Bearer {settings.groq_api_key}",
                "Content-Type": "application/json",
            }
            json_payload = {
                "model": "llama-3.1-8b-instant",
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                "response_format": {"type": "json_object"},
                "temperature": 0.3,
            }
            async with httpx.AsyncClient() as client:
                try:
                    resp = await client.post(
                        url,
                        json=json_payload,
                        headers=headers,
                        timeout=20.0,
                    )
                    if resp.status_code == 200:
                        reply = resp.json()["choices"][0]["message"]["content"]
                        return json.loads(reply)
                    else:
                        logger.error(
                            f"Groq API failed with status code {resp.status_code}: {resp.text}"
                        )
                except Exception as e:
                    logger.error(f"Groq AI Enrichment Failed: {e}")

        # 3. Try OpenRouter Fallback
        if settings.openrouter_api_key:
            logger.info("Falling back to OpenRouter for AI Enrichment...")
            url = "https://openrouter.ai/api/v1/chat/completions"
            headers = {
                "Authorization": f"Bearer {settings.openrouter_api_key}",
                "HTTP-Referer": "https://tatvik.ai",
                "X-Title": "Tatvik",
                "Content-Type": "application/json",
            }
            json_payload = {
                "model": "meta-llama/llama-3.1-8b-instruct:free",
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {
                        "role": "user",
                        "content": f"{user_prompt}\nReturn exactly a valid JSON object.",
                    },
                ],
                "response_format": {"type": "json_object"},
            }
            async with httpx.AsyncClient() as client:
                try:
                    resp = await client.post(
                        url,
                        json=json_payload,
                        headers=headers,
                        timeout=20.0,
                    )
                    if resp.status_code == 200:
                        reply = resp.json()["choices"][0]["message"]["content"]
                        clean_reply = (
                            reply.replace("```json", "").replace("```", "").strip()
                        )
                        return json.loads(clean_reply)
                    else:
                        logger.error(
                            f"OpenRouter API failed with status code {resp.status_code}: {resp.text}"
                        )
                except Exception as e:
                    logger.error(f"OpenRouter AI Enrichment Failed: {e}")

    def deduplicate(self, url: str) -> bool:
        """Check if item exists in PostgreSQL"""
        stmt = select(PulseItem).where(PulseItem.url == url)
        return self.db.scalar(stmt) is not None

    async def ingest_source(self, url: str, source_type: str = "rss"):
        """Pipeline execution per source"""
        logger.info(f"Tatvik Pulse Ingesting: {url} via {source_type}")

        # 1. Fetch
        items = []
        if source_type == "rss":
            items = await self.fetch_rss(url)
        elif source_type == "github":
            items = await self.fetch_github_api(url)

        # 2. Normalize & Deduplicate
        for item in items:
            if self.deduplicate(item["url"]):
                continue

            # 3. AI Summarize & Tag
            enriched = await self.ai_enrichment(item["title"], item["description"])

            # Proactively space out requests to stay within free-tier rate limits (15 RPM)
            if settings.gemini_api_key:
                await asyncio.sleep(4.0)

            # 4. Store
            db_item = PulseItem(
                title=item["title"],
                url=item["url"],
                description=item["description"],
                source=item["source"],
                language=item.get("language"),
                summary=enriched.get("summary", ""),
                tags=json.dumps(enriched.get("tags", [])),
                sentiment=enriched.get("sentiment", "neutral"),
                related_technologies=json.dumps(
                    enriched.get("related_technologies", [])
                ),
                metadata_blob=json.dumps(
                    {
                        "beginner_explanation": enriched.get("beginner_explanation"),
                        "advanced_explanation": enriched.get("advanced_explanation"),
                    }
                ),
                created_at=datetime.utcnow(),
            )

            self.db.add(db_item)
            # 5. Cognee (Mock Integration - Graph Store)
            logger.info(f"Would push {item['title']} to Cognee Knowledge Graph")

        self.db.commit()
        import gc

        gc.collect()


async def run_pulse_pipeline(db: Session):
    """Main scheduler trigger for Tatvik Pulse"""
    engine = PulseEngine(db)

    sources = [
        # General Programming & Product Discovery
        {"url": "https://news.ycombinator.com/rss", "type": "rss"},
        {"url": "https://dev.to/feed", "type": "rss"},
        {"url": "https://lobste.rs/rss", "type": "rss"},
        # GitHub Trends & Ecosystem
        {
            "url": "/search/repositories?q=stars:>10000+pushed:>2023-01-01&sort=stars&order=desc",
            "type": "github",
        },
        {"url": "https://github.com/advisories.atom", "type": "rss"},
        # AI & Research
        {"url": "https://huggingface.co/blog/feed.xml", "type": "rss"},
        {"url": "http://export.arxiv.org/rss/cs.AI", "type": "rss"},
        # Frameworks & Core Tech
        {"url": "https://reactjs.org/feed.xml", "type": "rss"},
        {"url": "https://nextjs.org/feed.xml", "type": "rss"},
        {"url": "https://blog.vuejs.org/feed.rss", "type": "rss"},
        # Cloud Providers
        {"url": "https://aws.amazon.com/blogs/aws/feed/", "type": "rss"},
        {"url": "https://azurecomcdn.azureedge.net/en-us/blog/feed/", "type": "rss"},
        # Big Tech Engineering Blogs
        {"url": "https://netflixtechblog.com/feed", "type": "rss"},
        {"url": "https://blog.cloudflare.com/rss/", "type": "rss"},
        {"url": "https://vercel.com/atom", "type": "rss"},
        {"url": "https://discord.com/blog/rss.xml", "type": "rss"},
        # Remote Jobs & Communities
        {"url": "https://remoteok.com/remote-jobs.rss", "type": "rss"},
        {
            "url": "https://weworkremotely.com/categories/remote-programming-jobs.rss",
            "type": "rss",
        },
    ]

    for src in sources:
        try:
            await engine.ingest_source(src["url"], src["type"])
            # Yield control and sleep to let garbage collection free up memory safely
            await asyncio.sleep(1.0)
        except Exception as e:
            logger.error(f"Failed to ingest source {src['url']}: {e}")
