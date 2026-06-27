import asyncio
import os
import sys

# Add backend directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.api.v1.endpoints.advanced import call_ai_json
from app.core.config import settings

async def main():
    print("Testing call_ai_json with 'fast' task type (NVIDIA API)")
    result = await call_ai_json("What is 2+2? Respond with JSON {'answer': 4}", task_type="fast")
    print(f"Result: {result}")

if __name__ == "__main__":
    asyncio.run(main())
