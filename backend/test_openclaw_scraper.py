import asyncio
import httpx
from app.core.config import settings

async def test_scraping():
    print(f"Connecting to OpenClaw API at: {settings.openclaw_api_url}")
    
    url = f"{settings.openclaw_api_url.rstrip('/')}/v1/chat/completions"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {settings.openclaw_api_key}"
    }
    
    payload = {
        "model": "openclaw",
        "messages": [
            {
                "role": "user", 
                "content": "Use your browser or web scraping plugin to read the content of https://krishpatel19.vercel.app/. Once you have read the site, provide a 2 sentence summary of what the website is about and who it belongs to."
            }
        ]
    }
    
    print("\nSending scraping task to OpenClaw...")
    async with httpx.AsyncClient() as client:
        try:
            # We use a long timeout because browser scraping and LLM processing takes time
            response = await client.post(url, json=payload, headers=headers, timeout=120.0)
            
            if response.status_code == 200:
                data = response.json()
                content = data.get("choices", [{}])[0].get("message", {}).get("content", "")
                print("\n--- OPENCLAW RESPONSE ---")
                print(content)
                print("-------------------------\n")
                print("SUCCESS: OpenClaw successfully scraped the site and responded!")
            else:
                print(f"ERROR {response.status_code}: {response.text}")
                
        except Exception as e:
            print(f"Failed to communicate with OpenClaw: {e}")

if __name__ == "__main__":
    asyncio.run(test_scraping())
