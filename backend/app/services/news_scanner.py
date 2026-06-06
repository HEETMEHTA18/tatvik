import logging
import xml.etree.ElementTree as ET
import httpx
from sqlalchemy.orm import Session
from sqlalchemy import select
from app.models.entities import TechNews
from datetime import datetime

logger = logging.getLogger(__name__)

FEEDS = ["https://news.ycombinator.com/rss", "https://techcrunch.com/feed/"]


async def scan_tech_news(db: Session):
    logger.info("Starting tech news RSS scan...")
    scanned_count = 0
    async with httpx.AsyncClient() as client:
        for url in FEEDS:
            try:
                response = await client.get(url, timeout=15.0)
                if response.status_code != 200:
                    logger.error(
                        f"Failed to fetch RSS feed {url}: {response.status_code}"
                    )
                    continue

                root = ET.fromstring(response.content)
                for item in root.findall(".//item"):
                    title = (
                        item.find("title").text
                        if item.find("title") is not None
                        else ""
                    )
                    link = (
                        item.find("link").text if item.find("link") is not None else ""
                    )
                    description = (
                        item.find("description").text
                        if item.find("description") is not None
                        else ""
                    )
                    pub_date = (
                        item.find("pubDate").text
                        if item.find("pubDate") is not None
                        else ""
                    )

                    if not title or not link:
                        continue

                    # Clean title and link from potential leading/trailing whitespaces
                    title = title.strip()
                    link = link.strip()

                    # Check if link already exists in DB
                    stmt = select(TechNews).where(TechNews.link == link)
                    existing = db.scalar(stmt)
                    if not existing:
                        news_item = TechNews(
                            title=title,
                            link=link,
                            description=(
                                description[:1000] if description else ""
                            ),  # truncate description if too long
                            published_at=pub_date,
                            scanned_at=datetime.utcnow(),
                        )
                        db.add(news_item)
                        scanned_count += 1

                db.commit()
            except Exception as e:
                logger.error(f"Error scanning feed {url}: {str(e)}")

    logger.info(f"RSS scan finished. Added {scanned_count} new articles.")
    return scanned_count
