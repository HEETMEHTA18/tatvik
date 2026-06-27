import logging
import asyncio
import httpx
from sqlalchemy.orm import Session
from app.db.base import Base
from app.db.session import SessionLocal, engine
from app.services.pulse_engine import PulseEngine
from app.models.entities import PulseItem
from app.core.config import settings

logging.basicConfig(level=logging.INFO)


async def test_huggingface_ping():
    print("\n--- Testing Hugging Face OpenClaw Space ---")
    url = "https://heetmehta18-openclaw-devmentor.hf.space"
    print(f"Pinging {url}...")
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, timeout=15.0)
            print(f"Status Code: {resp.status_code}")
            if resp.status_code < 500:
                print("SUCCESS: Hugging Face space is alive and reachable!")
            else:
                print(f"WARNING: Space returned {resp.status_code}")
    except Exception as e:
        print(f"ERROR: Failed to ping Hugging Face space: {e}")


async def test_pulse_ingestion():
    print("\n--- Testing Tatvik Pulse Ingestion ---")
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    # Clear existing PulseItem entries to force fresh ingestion and Gemini API calls
    db.query(PulseItem).delete()
    db.commit()
    pulse_engine = PulseEngine(db)

    # We will test fetching just one RSS feed for speed
    test_source = {"url": "https://dev.to/feed", "type": "rss"}

    print(f"Ingesting from test source: {test_source['url']}")
    try:
        await pulse_engine.ingest_source(test_source["url"], test_source["type"])
        print("SUCCESS: Ingestion completed without exceptions.")

        # Verify items were saved to the database
        items = db.query(PulseItem).order_by(PulseItem.created_at.desc()).limit(5).all()
        print(f"\nFound {len(items)} items in the database:")
        for idx, item in enumerate(items):
            print(f"{idx+1}. {item.title}")
            print(f"   Source: {item.source}")
            print(
                f"   Summary: {item.summary[:100]}..."
                if item.summary
                else "   Summary: None"
            )
            print(f"   Tags: {item.tags}")
            print("-" * 50)

    except Exception as e:
        print(f"ERROR during pulse ingestion: {e}")
    finally:
        db.close()


async def run_all_tests():
    await test_huggingface_ping()
    await test_pulse_ingestion()


if __name__ == "__main__":
    asyncio.run(run_all_tests())
