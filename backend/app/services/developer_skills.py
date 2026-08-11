"""
Developer Skills Registry
=========================
Frontend + backend developer skills drawn from:
  - AutoDevs.dev CLI  (https://autodevs.dev) developer profiles
  - skills.sh         (https://skills.sh) agent skill directory

The mission agent loads these skills and applies the matching guidance when it
understands a repository and plans changes, so generated PRs respect the
project's stack, conventions, and engineering practices instead of producing
generic placeholder code.

Also ingests the developer's own skill/prompt list (`.autodevs/prompts.md`,
the AutoDevs prompt-history file) as evidence of what this developer works on.
"""

from __future__ import annotations

import logging
from pathlib import Path

logger = logging.getLogger(__name__)

# ── Skills registry ───────────────────────────────────────────────────────────

FRONTEND_SKILLS: list[dict] = [
    {
        "id": "frontend-design",
        "source": "skills.sh/anthropics/frontend-design",
        "summary": "Build pixel-faithful, accessible UIs that follow the repo's existing design system and component library.",
        "rules": [
            "Reuse the existing component/widget library; do not introduce a second design language.",
            "Match the repo's theming (colors, spacing, typography, dark-mode tokens).",
            "Keep interactions accessible (contrast, hit targets, semantics, reduced motion).",
        ],
    },
    {
        "id": "web-design-guidelines",
        "source": "skills.sh/vercel-labs/web-design-guidelines",
        "summary": "Responsive, fast, polished web UI work.",
        "rules": [
            "Respect breakpoints and touch targets.",
            "Keep bundle/asset weight low; lazy-load heavy screens.",
            "Follow the repo's glassmorphism / Material 3 constraints.",
        ],
    },
    {
        "id": "flutter-best-practices",
        "source": "autodevs.dev/flutter-developer",
        "summary": "Flutter/Dart cross-platform mobile code that compiles and matches the project layout.",
        "rules": [
            "Follow the repo folder layout (lib/core, lib/features, lib/widgets, lib/services).",
            "Use the repo's state-management pattern (Riverpod/providers); do not scatter setState hacks.",
            "Keep `flutter analyze` clean (no fatal warnings); update pubspec only when necessary.",
        ],
    },
    {
        "id": "ui-consistency",
        "source": "skills.sh/leonxlnx/taste-skill",
        "summary": "Keep UI cohesive with the existing screens so new screens feel native.",
        "rules": [
            "Mirror the spacing and radii used on neighboring screens.",
            "Reuse existing widgets (glass cards, stat rows, chips, charts) instead of inventing new ones.",
        ],
    },
]

BACKEND_SKILLS: list[dict] = [
    {
        "id": "fastapi-rest",
        "source": "autodevs.dev/backend-developer",
        "summary": "FastAPI REST services with typed schemas, dependency injection, and validation.",
        "rules": [
            "Define request/response models via Pydantic schemas under app/schemas.",
            "Register routers under app/api/v1/endpoints using the v1 prefix.",
            "Keep business logic in app/services and persistence in app/repositories.",
        ],
    },
    {
        "id": "tdd",
        "source": "skills.sh/mattpocock/tdd",
        "summary": "Write tests alongside code.",
        "rules": [
            "Add backend/tests coverage for new behavior.",
            "Keep tests deterministic; mock external HTTP/AI calls.",
        ],
    },
    {
        "id": "code-review",
        "source": "skills.sh/mattpocock/code-review",
        "summary": "Self-review changes against quality gates, security, and performance before opening a PR.",
        "rules": [
            "Never commit secrets; read credentials from settings/env only.",
            "Handle expected failures gracefully with warnings, not stack traces.",
            "Respect the repo's code style (black + flake8).",
        ],
    },
    {
        "id": "diagnosing-bugs",
        "source": "skills.sh/mattpocock/diagnosing-bugs",
        "summary": "Reproduce, isolate, then fix root causes.",
        "rules": [
            "Prefer the smallest change that fixes the root cause.",
            "Add a regression test for each bug fix.",
        ],
    },
    {
        "id": "improve-codebase-architecture",
        "source": "skills.sh/mattpocock/improve-codebase-architecture",
        "summary": "Refactor toward the repo's documented modular architecture.",
        "rules": [
            "Keep the bounded-context split intact; do not merge service layers.",
            "Prefer additive, backward-compatible changes.",
        ],
    },
]

AUTODEV_PROFILES: list[str] = [
    "Web Developer",
    "ML Engineer",
    "Flutter Developer",
    "DevOps Engineer",
    "Backend Developer",
    "Full-Stack AI Dev",
]


def _autodev_prompts_path() -> Path | None:
    """Locate `.autodevs/prompts.md` (repo root) regardless of cwd."""
    candidates = [
        Path.cwd() / ".autodevs" / "prompts.md",
        Path.cwd().parent / ".autodevs" / "prompts.md",
        Path(__file__).resolve().parents[3] / ".autodevs" / "prompts.md",
    ]
    for p in candidates:
        if p.exists():
            return p
    return None


def load_autodev_prompts(max_chars: int = 4000) -> str:
    """Read the developer's AutoDevs prompt/skill list as skill evidence."""
    path = _autodev_prompts_path()
    if not path:
        return ""
    try:
        return path.read_text(encoding="utf-8")[:max_chars]
    except Exception as e:
        logger.warning(f"Could not read autodev prompts: {e}")
        return ""


def detect_stack(languages: list[str], file_tree: list[str]) -> dict:
    """Classify the repository stack so the right skills get attached."""
    stack = {"frontend": [], "backend": [], "mobile": False, "web": False}
    tree = " ".join(file_tree[:400])
    if ".dart" in tree or "lib/" in tree:
        stack["mobile"] = True
        stack["frontend"].append("flutter-best-practices")
    if (
        "package.json" in tree
        or "node_modules" in tree
        or ".tsx" in tree
        or ".ts" in tree
    ):
        stack["web"] = True
        stack["frontend"].append("frontend-design")
        stack["frontend"].append("web-design-guidelines")
    if "backend/" in tree or ".py" in tree:
        stack["backend"].append("fastapi-rest")
    if "backend/tests" in tree or "test" in tree or "tests/" in tree:
        stack["backend"].append("tdd")
    if ".github/" in tree or "Dockerfile" in tree or "vercel.json" in tree:
        stack["backend"].append("improve-codebase-architecture")
    # Always attach cross-cutting review/bug skills.
    stack["backend"].append("code-review")
    stack["backend"].append("diagnosing-bugs")
    return stack


def build_skills_context(languages: list[str], file_tree: list[str]) -> str:
    """Render a skills block that the mission agent should apply."""
    stack = detect_stack(languages, file_tree)
    selected: list[dict] = []
    seen: set[str] = set()
    for sid in stack["frontend"] + stack["backend"]:
        if sid in seen:
            continue
        seen.add(sid)
        skill = next(
            (s for s in FRONTEND_SKILLS + BACKEND_SKILLS if s["id"] == sid), None
        )
        if skill:
            selected.append(skill)

    if not selected:
        return ""

    parts = ["DEVELOPER SKILLS TO APPLY:"]
    for skill in selected:
        parts.append(f"\n### {skill['id']} ({skill['source']})")
        parts.append(skill["summary"])
        for rule in skill["rules"]:
            parts.append(f"- {rule}")

    prompts = load_autodev_prompts()
    if prompts:
        parts.append("\nDEVELOPER PROMPT/SKILL HISTORY (.autodevs/prompts.md):")
        parts.append(prompts)

    return "\n".join(parts)


def skills_registry() -> dict:
    """Public registry used by the /skills endpoint."""
    return {
        "profiles": AUTODEV_PROFILES,
        "frontend": FRONTEND_SKILLS,
        "backend": BACKEND_SKILLS,
        "autodev_prompts_loaded": bool(load_autodev_prompts()),
    }
