"""
AI OS Layer Integration Tests
Tests Cognee long-term memory and OpenClaw agentic action services.
"""

import asyncio
import sys
import os

# Load env vars from .env file
from dotenv import load_dotenv

load_dotenv()

sys.path.append(os.path.abspath(os.path.dirname(__file__)))

from app.services.cognee_service import CogneeService
from app.services.openclaw_service import OpenClawService

GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
RESET = "\033[0m"
BOLD = "\033[1m"


def ok(msg):
    print(f"  {GREEN}✅ PASS{RESET}  {msg}")


def fail(msg):
    print(f"  {RED}❌ FAIL{RESET}  {msg}")


def warn(msg):
    print(f"  {YELLOW}⚠️  WARN{RESET}  {msg}")


def info(msg):
    print(f"  {BLUE}ℹ️  INFO{RESET}  {msg}")


# ─────────────────────────────────────────────
# COGNEE TESTS
# ─────────────────────────────────────────────
async def test_cognee():
    print(f"\n{BOLD}{'─'*50}{RESET}")
    print(f"{BOLD}  🧠  COGNEE LONG-TERM MEMORY TESTS{RESET}")
    print(f"{BOLD}{'─'*50}{RESET}")

    service = CogneeService()

    # Test 1: Service initialisation
    if service.enabled:
        ok(f"CogneeService initialised. API Key: {service.api_key[:8]}...")
    else:
        warn("CogneeService in stub/dry-run mode (no API key)")

    # Test 2: Add developer profile
    print(f"\n  [Test] Adding developer profile for user 'test_user_001'...")
    result = await service.add_developer_profile(
        user_id="test_user_001",
        profile_data={
            "name": "Heet Mehta",
            "skills": ["Python", "FastAPI", "Flutter", "React"],
            "weaknesses": ["System Design", "Kubernetes"],
            "last_project": "DevMentor AI OS",
            "goal": "Become a Full-Stack AI Engineer",
        },
    )
    if result:
        ok("add_developer_profile() returned True")
    else:
        fail("add_developer_profile() returned False")

    # Test 3: Get developer profile
    print(f"\n  [Test] Retrieving developer profile for user 'test_user_001'...")
    profile = await service.get_developer_profile("test_user_001")
    if profile and isinstance(profile, dict):
        ok(f"get_developer_profile() returned: {str(profile)[:120]}...")
    else:
        fail(f"get_developer_profile() returned unexpected: {profile}")

    # Test 4: Index a repository
    print(f"\n  [Test] Indexing a mock repository...")
    index_result = await service.index_repository(
        user_id="test_user_001",
        repo_name="devmentor",
        codebase_files=[
            {"path": "backend/app/main.py", "content": "FastAPI app entry point"},
            {
                "path": "backend/app/core/config.py",
                "content": "Pydantic settings with Cognee + OpenClaw keys",
            },
        ],
    )
    if index_result:
        ok("index_repository() returned True")
    else:
        fail("index_repository() returned False")

    # Test 5: Query repository memory
    print(f"\n  [Test] Querying repository memory...")
    query_result = await service.query_repository_memory(
        user_id="test_user_001",
        repo_name="devmentor",
        query="What does the config module do?",
    )
    if isinstance(query_result, list):
        ok(f"query_repository_memory() returned list with {len(query_result)} item(s)")
    else:
        fail(f"query_repository_memory() returned unexpected: {query_result}")


# ─────────────────────────────────────────────
# OPENCLAW TESTS
# ─────────────────────────────────────────────
async def test_openclaw():
    print(f"\n{BOLD}{'─'*50}{RESET}")
    print(f"{BOLD}  🤖  OPENCLAW AGENT ACTION TESTS{RESET}")
    print(f"{BOLD}{'─'*50}{RESET}")

    service = OpenClawService()

    # Test 1: Service initialisation
    if service.enabled:
        ok(f"OpenClawService initialised. URL: {service.api_url}")
        ok(f"API Key: {service.api_key[:8]}...")
    else:
        warn("OpenClawService in dry-run mode (no API key)")

    # Test 2: Execute a task
    print(f"\n  [Test] Dispatching a coding task to OpenClaw...")
    task_result = await service.execute_task(
        repo_url="https://github.com/heetmehta18/devmentor",
        task_description="Add a /health endpoint that returns status: ok and version: 1.0",
        branch_name="feature/health-endpoint",
    )
    if task_result and isinstance(task_result, dict):
        if task_result.get("stub"):
            warn(f"execute_task() ran in stub mode: {task_result.get('message')}")
            ok("PR URL (stub): " + task_result.get("pull_request_url", "N/A"))
        elif task_result.get("success"):
            ok(f"execute_task() LIVE success: {task_result}")
        else:
            fail(f"execute_task() returned error: {task_result.get('error')}")
    else:
        fail(f"execute_task() returned unexpected: {task_result}")

    # Test 3: Run a terminal command
    print(f"\n  [Test] Running a terminal command via OpenClaw...")
    cmd_result = await service.run_terminal_command("echo 'Hello from OpenClaw agent!'")
    if cmd_result and isinstance(cmd_result, dict):
        if cmd_result.get("stub"):
            warn(f"run_terminal_command() ran in stub mode: {cmd_result.get('output')}")
        elif cmd_result.get("success"):
            ok(f"run_terminal_command() LIVE output: {cmd_result.get('output')}")
        else:
            fail(f"run_terminal_command() error: {cmd_result.get('error')}")
    else:
        fail(f"run_terminal_command() returned unexpected: {cmd_result}")


# ─────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────
async def main():
    print(f"\n{BOLD}{'═'*50}")
    print(f"   DevMentor AI OS — Integration Test Suite")
    print(f"{'═'*50}{RESET}")

    await test_cognee()
    await test_openclaw()

    print(f"\n{BOLD}{'═'*50}")
    print(f"   All tests completed.")
    print(f"{'═'*50}{RESET}\n")


if __name__ == "__main__":
    asyncio.run(main())
