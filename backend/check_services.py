import asyncio
import httpx
import os
import sys
from dotenv import load_dotenv

# Load root env
load_dotenv()

# Add parent path to import app modules
sys.path.append(os.path.abspath(os.path.dirname(__file__)))

from app.core.config import settings
from app.services.cognee_service import CogneeService
from app.services.openclaw_service import OpenClawService


async def test_openclaw():
    print("=== Testing OpenClaw Connection ===")
    url = settings.openclaw_api_url
    key = settings.openclaw_api_key
    print(f"Target URL: {url}")
    print(f"API Key configured: {bool(key)}")

    headers = {"Content-Type": "application/json"}
    if key:
        headers["Authorization"] = f"Bearer {key}"

    async with httpx.AsyncClient() as client:
        try:
            # First, check basic GET status of the space
            response = await client.get(url, timeout=10.0)
            print(f"HTTP GET Root Status Code: {response.status_code}")

            # Try calling /health or similar if available
            health_response = await client.get(f"{url}/health", timeout=10.0)
            print(f"HTTP GET /health Status Code: {health_response.status_code}")
            print(f"Health Response Content: {health_response.text[:200]}")
        except Exception as e:
            print(f"Error connecting to OpenClaw: {e}")


async def test_cognee():
    print("\n=== Testing Cognee Connection ===")
    print(f"Cognee API Key configured: {bool(settings.cognee_api_key)}")
    print(f"Gemini API Key configured: {bool(settings.gemini_api_key)}")

    service = CogneeService()
    print(f"Cognee service active state: {service.enabled}")

    try:
        import cognee

        print("Successfully imported local 'cognee' library.")
    except ImportError:
        print(
            "Warning: local 'cognee' package is not installed in this environment yet. (Install via: pip install -r requirements.txt)"
        )


async def main():
    await test_openclaw()
    await test_cognee()


if __name__ == "__main__":
    asyncio.run(main())
