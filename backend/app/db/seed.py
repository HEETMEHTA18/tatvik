import uuid
import logging
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.models.user import User
from app.models.entities import GithubProfile, Repository, PromptHistory

logger = logging.getLogger(__name__)


def seed_database(db: Session):
    try:
        old_uid = "d57475f9-1f44-4508-81c0-f4ec33dacb06"
        new_uid = "05947977-be13-4144-8e2f-e769d87613dc"

        user_ids = [old_uid, new_uid]

        # 1. Seed users if they don't exist
        for idx, uid in enumerate(user_ids):
            user = db.scalar(select(User).where(User.id == uid))
            if not user:
                email = (
                    "HEETMEHTA18@github.com" if idx == 0 else "heet18_alt@github.com"
                )
                db_user = User(
                    id=uid,
                    email=email,
                    name="Heet Mehta",
                    username="HEETMEHTA18",
                    avatar_url="https://avatars.githubusercontent.com/u/181580508?v=4",
                    hashed_password="$pbkdf2-sha256$29000$Tcl5r5XSGuN8j7GWklIKIQ$V.eYJg3plEInhvPAf/E/EVFHlPyLoqi8NG4oG8bVFVY",
                    is_active=True,
                    personal_goal="Become a Senior Flutter & Full Stack Developer",
                    preferred_stack="Flutter, Dart, FastAPI, Python",
                )
                db.add(db_user)
                logger.info(f"Seeded user: {uid}")

        db.commit()

        # 2. Seed GitHub Profiles
        for uid in user_ids:
            profile = db.scalar(
                select(GithubProfile).where(GithubProfile.user_id == uid)
            )
            if not profile:
                db_profile = GithubProfile(
                    id=str(uuid.uuid4()),
                    user_id=uid,
                    login="HEETMEHTA18",
                    access_token="gho_" + "pwtSZHJkvasok5MZRtIieRi5tt0y7J3pBM0R",
                    synced_at=datetime.utcnow(),
                )
                db.add(db_profile)
                logger.info(f"Seeded github profile for user: {uid}")

        # 3. Seed Repositories
        for uid in user_ids:
            count = db.scalar(select(Repository).where(Repository.user_id == uid))
            if not count:
                # Add tatvik and autodev repositories as defaults
                repos = [
                    {
                        "full_name": "HEETMEHTA18/tatvik",
                        "name": "tatvik",
                        "description": "Premium developer mentor coach with prompt intelligence telemetry and iOS liquid glass navigation.",
                    },
                    {
                        "full_name": "HEETMEHTA18/autodev",
                        "name": "autodev",
                        "description": "AutoDev AI Agent framework for automated CLI development telemetry.",
                    },
                ]
                for r in repos:
                    db_repo = Repository(
                        id=str(uuid.uuid4()),
                        user_id=uid,
                        full_name=r["full_name"],
                        owner="HEETMEHTA18",
                        name=r["name"],
                        description=r["description"],
                        language="Dart" if r["name"] == "tatvik" else "Go",
                        difficulty="Intermediate",
                        impact_score=95,
                        why_recommended="Active development repository with high volume of commits.",
                        stars_count=10,
                        forks_count=2,
                        watchers_count=5,
                        open_issues_count=0,
                    )
                    db.add(db_repo)
                logger.info(f"Seeded default repositories for user: {uid}")

        # 4. Seed Prompt History if empty
        for uid in user_ids:
            exists = db.scalar(
                select(PromptHistory).where(PromptHistory.user_id == uid)
            )
            if not exists:
                prompts = [
                    {
                        "original": "Upgrade the bottom navigation bar to an Apple Liquid Glass aesthetic using custom BackdropFilter, glass-morphism borders, and smooth translation transitions.",
                        "refined": "Create a premium bottom navigation bar inspired by the Apple Liquid Glass design language. Implement a custom BackdropFilter with a high-blur value, subtle gradient borders using glass-morphism style, and smooth translation animations on tab changes.",
                        "score": 92,
                        "technologies": "Flutter, Dart, CSS",
                        "workflow": "Feature Building",
                        "project": "tatvik",
                        "days_ago": 1,
                    },
                    {
                        "original": "How can I prevent the walkthrough tutorial overlay from intercepting pointer events in my widget test?",
                        "refined": "Explain the technique to ignore or bypass pointer events from an overlay (such as a walkthrough tutorial) in Flutter widget tests. Describe the usage of the IgnorePointer widget or mocked preferences to prevent hit-testing obstruction.",
                        "score": 88,
                        "technologies": "Flutter, Dart, Testing",
                        "workflow": "Testing",
                        "project": "tatvik",
                        "days_ago": 2,
                    },
                    {
                        "original": "Why does tester.pumpAndSettle() time out in my Flutter widget tests when testing pages with a repeating background animation, and how do I fix it?",
                        "refined": "Analyze the cause of WidgetTester.pumpAndSettle() timing out in Flutter widget tests when an active, infinite animation loop is running (e.g., custom background animation). Explain how to replace it with duration-based pumps to verify state transitions without waiting for the animation to end.",
                        "score": 95,
                        "technologies": "Flutter, Dart, Testing",
                        "workflow": "Debugging",
                        "project": "tatvik",
                        "days_ago": 3,
                    },
                    {
                        "original": "Write a FastAPI endpoint /api/v1/prompts/sync-github to scan public and private GitHub repositories for .autodevs/prompts.md.",
                        "refined": "Implement a secure endpoint `/api/v1/prompts/sync-github` in FastAPI. It should extract the user's Github access token, fetch public/private repositories using GitHub REST API, read the content of `.autodevs/prompts.md` in each, base64 decode it, and parse the lines into structured PromptHistory records.",
                        "score": 90,
                        "technologies": "FastAPI, Python, GitHub API",
                        "workflow": "Feature Building",
                        "project": "tatvik",
                        "days_ago": 4,
                    },
                    {
                        "original": "Create a responsive custom glass container widget in Flutter that applies light source gradient reflections, box shadows, and a high-contrast theme border.",
                        "refined": "Develop a Flutter custom painter or container widget that renders a glassmorphic card. Add a light source diagonal gradient to simulate reflection, configure refined box shadows, and apply a thin, high-contrast border aligned with a dark theme.",
                        "score": 85,
                        "technologies": "Flutter, Dart",
                        "workflow": "Feature Building",
                        "project": "tatvik",
                        "days_ago": 5,
                    },
                    {
                        "original": "Optimize my PWA manifest.json configuration to support custom Apple touch icon sizes (180x180, 192x192, 512x512) and configure the app shortcut entries.",
                        "refined": "Revise the PWA configuration files (manifest.json, index.html) for a Flutter Web project. Define high-resolution icons (180x180 for iOS, 192x192 and 512x512 for Android), include the 'apple-touch-icon' link meta tags, and configure PWA app shortcuts.",
                        "score": 89,
                        "technologies": "HTML, PWA, JSON",
                        "workflow": "DevOps",
                        "project": "tatvik",
                        "days_ago": 6,
                    },
                    {
                        "original": "How do I write a bash script to run my dev server in the background and monitor its status via healthcheck endpoints?",
                        "refined": "Provide a shell script that starts a FastAPI development server in the background, redirects logs to a logfile, and loops a curl healthcheck command with a timeout until the server is fully ready and responsive.",
                        "score": 82,
                        "technologies": "Bash, Shell, Linux",
                        "workflow": "DevOps",
                        "project": "tatvik",
                        "days_ago": 7,
                    },
                ]

                for p in prompts:
                    db_prompt = PromptHistory(
                        id=str(uuid.uuid4()),
                        user_id=uid,
                        original_prompt=p["original"],
                        refined_prompt=p["refined"],
                        score=p["score"],
                        technologies=p["technologies"],
                        workflow=p["workflow"],
                        project_name=p["project"],
                        created_at=datetime.utcnow() - timedelta(days=p["days_ago"]),
                        session_id=str(uuid.uuid4()),
                        prompt_id=str(uuid.uuid4()),
                        response="This is a generated AI response for the refined prompt.",
                    )
                    db.add(db_prompt)
                logger.info(f"Seeded prompt history for user: {uid}")

        db.commit()
        logger.info("Database self-healing/seeding ran successfully.")
    except Exception as e:
        db.rollback()
        logger.error(f"Error seeding database: {e}")
