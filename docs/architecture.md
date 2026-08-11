# Tatvik Architecture

## System Overview
Tatvik uses a production-oriented, modular, service-based architecture built for mobile-first developer intelligence. The frontend is a Flutter application, the backend is a FastAPI service, and stateful data is persisted in PostgreSQL with Redis for caching and rate limiting.

The system is designed around four core layers:

1. **Presentation layer** — Flutter app with Material 3, glassmorphism components, and route-based feature modules.
2. **Application layer** — FastAPI controllers, dependency injection, validation, and orchestration logic.
3. **Domain/data layer** — Repository pattern, service layer, and PostgreSQL persistence.
4. **Integration layer** — GitHub REST/GraphQL APIs, OAuth providers, OpenAI GPT-5, Ollama, Supabase storage, and Redis.

## Architectural Principles
- **Mobile-first and premium**: dark-mode-first glass UI with responsive layouts.
- **Modular monolith backend**: one deployable API with clear bounded contexts.
- **API-first development**: backend contracts are versioned and documented.
- **Security by default**: JWT auth, encrypted secrets, secure OAuth flows, and RBAC-ready design.
- **Observability**: structured logging, request IDs, health checks, and audit-friendly events.
- **Scalable AI orchestration**: provider abstraction for OpenAI and Ollama.

## Frontend Architecture

### Recommended Flutter Structure
- `core/` for config, theme tokens, constants, and shared utilities.
- `features/` for domain modules: auth, dashboard, analysis, repositories, roadmap, mentor, discover, and profile.
- `services/` for API clients, auth/session management, and analytics.
- `models/` for DTOs and immutable data classes.
- `routes/` for GoRouter route definitions and guards.
- `widgets/` for reusable UI building blocks like glass cards, stat rows, chips, and charts.

### Frontend Responsibilities
- Render onboarding, auth, dashboard, analysis, discovery, mentor, roadmap, and settings screens.
- Manage local state with Riverpod.
- Handle route-level loading and error states.
- Persist session metadata securely.
- Call backend APIs and transform API DTOs into UI models.

### Frontend Design Constraints
- Material 3 design system.
- Glassmorphism surfaces with blur, subtle borders, and depth.
- Accessibility support for contrast, text scaling, and semantics.
- Hero animations and micro-interactions for premium feel.

## Backend Architecture

### FastAPI Application Structure
- `app/main.py` bootstraps the application.
- `app/api/v1/endpoints/` contains feature-specific routers.
- `app/core/` handles config, security, logging, rate limiting, and common dependencies.
- `app/db/` manages database sessions and migrations.
- `app/models/` contains SQLAlchemy models.
- `app/schemas/` contains Pydantic request/response models.
- `app/repositories/` encapsulates persistence logic.
- `app/services/` contains business logic, GitHub adapters, and AI orchestration.

### Backend Responsibilities
- Authenticate users through GitHub, Google, and email login flows.
- Issue and validate JWT access tokens and refresh tokens.
- Fetch and normalize GitHub data.
- Generate developer scores, skill gaps, roadmaps, recommendations, and mentor responses.
- Store all persistent artifacts in PostgreSQL.
- Cache expensive responses and rate-limit abusive traffic using Redis.

## Data Architecture

### Primary Stores
- **PostgreSQL on Neon**: source of truth for users, profiles, scores, skill gaps, roadmaps, chats, and recommendations.
- **Redis**: response caching, token/session throttling, job coordination, and short-lived AI response caches.
- **Supabase Storage**: optional storage for avatars, attachments, and generated assets.

### Data Modeling Strategy
- Use UUID primary keys across all primary entities.
- Track `created_at`, `updated_at`, and soft-delete fields where helpful.
- Use JSONB for flexible AI output payloads, but keep core relationships relational.
- Separate read-heavy generated artifacts from core identity tables.

## AI and Recommendation Architecture

### AI Services
- **Analysis Engine**: profiles repositories, commit history, languages, README quality, and contribution signals.
- **Skill Gap Engine**: compares user skill profile with target role expectations.
- **Roadmap Generator**: creates milestones, timelines, and project milestones.
- **Mentor Chat Engine**: conversational guidance using user context and current progress.
- **Project/Repository Recommender**: ranks projects based on learning value, difficulty, and impact.

### Model Provider Abstraction
The backend should expose one interface for LLM providers:
- OpenAI GPT-5 for hosted inference.
- Ollama for local development and privacy-preserving deployments.

This allows prompt templates, guardrails, and output schemas to stay consistent across providers.

## Authentication Flow
1. User starts login in Flutter.
2. Flutter redirects to OAuth provider or submits email credentials.
3. Backend validates provider response and creates/updates user records.
4. Backend issues JWT access and refresh tokens.
5. Flutter stores tokens securely and attaches them to API requests.
6. Middleware verifies tokens and injects the authenticated user into route handlers.

## Request Lifecycle
1. Flutter sends request through a typed API client.
2. FastAPI dependency stack authenticates, validates, and rate limits the request.
3. Router delegates to a service.
4. Service may call a repository, GitHub API, Redis cache, or AI provider.
5. Response is normalized by a response schema and returned to Flutter.

## Deployment Topology
- **Frontend**: Flutter builds distributed via Firebase Hosting for web preview and mobile stores for iOS/Android.
- **Backend**: FastAPI hosted on Railway.
- **Database**: PostgreSQL hosted on Neon.
- **Cache**: Managed Redis instance.
- **Storage**: Supabase Storage.
- **CI/CD**: GitHub Actions pipelines for lint, test, build, and deploy.

## Command Center — Mission-to-PR Pipeline

The Command Center lets a user create a development mission and have the AI OS
execute it end-to-end, ending in a real pull request on a target repository.

### Flow
1. **Flutter frontend** `POST /api/v1/openclaw/missions` with `title`, `description`, `repository`, and `execute=true`.
2. **FastAPI** records the mission in the pipeline tracker and schedules `_run_mission_in_background`.
3. **Repository understanding** — `MissionPrService.understand_repository` combines the Cognee knowledge graph (previous missions, architecture memory) with the live GitHub file tree, key files, README, and a skill fingerprint, producing a rendered context block.
4. **Stages** — the mission advances through 8 tracker stages (Requirement → Planning → Design → Development → Testing → Review → Deployment → Memory). To protect the HuggingFace free tier the stages are **batched into 3 gateway dispatches** (instead of 8) and per-stage outputs are cached in-process; replies are split locally from a single JSON response.
5. **Gateway execution** — each dispatch goes to the OpenClaw gateway (`OPENCLAW_API_URL`, an HF Space) via `OpenClawService._dispatch`. The gateway runs its agent (Gemini) and returns structured text.
6. **PR creation** — `MissionPrService.execute_mission_and_open_pr` asks the LLM for a strict-JSON change plan (`_plan_changes`), creates a `tatvik/mission-*` branch, writes files through the GitHub Contents API, and opens a formatted PR.

### Model orchestration & free-tier protection
`call_gemini` (research.py) is the backend's LLM entry point. Because the
Gemini free tier trips `429 RESOURCE_EXHAUSTED` on bursts, it now enforces:

- **Concurrency limiter** — at most `gemini_max_concurrency` in-flight requests.
- **Rate spacing** — minimum `gemini_rate_min_interval` between calls.
- **Circuit breaker** — trips after `gemini_circuit_threshold` consecutive quota errors and cools down for `gemini_circuit_cool_down` seconds.
- **Response cache** — identical prompts (retries/duplicate dispatches) short-circuit in-process for `gemini_cache_ttl` seconds.
- **Model fallback** — `gemini-2.5-flash` → `gemini-2.5-flash-lite`, then NVIDIA (`meta/llama-3.3-70b-instruct`) as last resort.
- **Bootstrap guard** — the gateway sometimes answers its own "Who am I?" persona prompt instead of the request; `OpenClawService` detects these canned replies and fails fast rather than recording bogus output or re-dispatching.

### Developer skills
The mission agent loads the developer skills registry
(`app/services/developer_skills.py`) built from **AutoDevs.dev** developer
profiles and the **skills.sh** skill directory, plus the developer's own
`.autodevs/prompts.md` list. Detected stack (Flutter/mobile, web, FastAPI,
pytest, CI) selects the relevant frontend/backend skills, which are injected
into the repository context and the change-plan prompt so generated PRs match
the repo's conventions and are significant, working changes — not stubs.

### Diagram
```text
Flutter Command Center
        |
        | POST /api/v1/openclaw/missions
        v
FastAPI Pipeline Tracker (8 stages, batched + cached)
        |
        +-- Understand repo: Cognee graph + GitHub tree + skills fingerprint
        |
        +-- OpenClaw (HF Space) gateway  --3 dispatches-->  agent (Gemini)
        |        |                                        (bootstrap guard)
        |        +-- Gemini retry/fallback   <- circuit breaker + rate guard
        |        +-- NVIDIA fallback
        |
        +-- MissionPrService: plan (JSON) -> branch -> files -> pull request
```

## Non-Functional Requirements
- P95 API latency targets for common reads should stay low through caching.
- API responses should be deterministic and versioned.
- Background operations must be idempotent where possible.
- Secrets must remain outside source control.
- All external integrations should fail gracefully with fallback states in the UI.

## High-Level Diagram
```text
Flutter App (Material 3 + Riverpod + GoRouter)
        |
        | HTTPS / JSON / JWT
        v
FastAPI API Gateway Layer
        |
        +--> Service Layer --> Repository Layer --> PostgreSQL (Neon)
        |
        +--> Redis Cache / Rate Limiter
        |
        +--> GitHub REST + GraphQL APIs
        |
        +--> AI Provider Adapter (OpenAI GPT-5 / Ollama)
        |
        +--> Supabase Storage (avatars/assets)
```
