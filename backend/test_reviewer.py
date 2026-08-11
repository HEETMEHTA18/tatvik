import asyncio
from app.services.openclaw_service import OpenClawService


async def main():
    service = OpenClawService()
    print("Sending request to OpenClaw...")
    result = await service.execute_task(
        repo_url="https://github.com/HEETMEHTA18/tatvik",
        task_description="Analyze architecture",
        branch_name="main",
    )
    print("Result:", result)


if __name__ == "__main__":
    asyncio.run(main())
