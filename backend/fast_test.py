import asyncio
from app.db.base import Base
from app.db.session import SessionLocal, engine
from app.models.entities import PulseItem
from app.services.pulse_engine import PulseEngine

async def run():
    print("Creating tables...")
    Base.metadata.create_all(bind=engine)
    
    db = SessionLocal()
    pulse = PulseEngine(db)
    
    print("Fetching RSS...")
    items = await pulse.fetch_rss("https://dev.to/feed")
    items = items[:1] # Only take 1 item to be fast
    
    print(f"Enriching {items[0]['title']}...")
    enriched = await pulse.ai_enrichment(items[0]['title'], items[0]['description'])
    
    print(f"Summary: {enriched.get('summary')}")
    print(f"Sentiment: {enriched.get('sentiment')}")
    print(f"Tags: {enriched.get('tags')}")

if __name__ == "__main__":
    asyncio.run(run())
