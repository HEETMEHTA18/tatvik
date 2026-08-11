# Tatvik Architecture --- Production Architecture Plan

## 1. Purpose

Tatvik is a mobile-first developer intelligence and AI development
operating system. The architecture is designed to:

-   Analyze a developer's GitHub profile and repositories.
-   Build a developer skill/profile representation.
-   Generate skill-gap analysis, learning roadmaps, recommendations, and
    mentor conversations.
-   Ingest and maintain repository knowledge for AI-assisted
    development.
-   Execute development missions through an AI agent pipeline.
-   Produce real pull requests against GitHub repositories.
-   Keep the backend modular so individual bounded contexts can later be
    extracted into services if scale requires it.

The current architecture remains a **modular monolith** rather than
prematurely splitting the system into microservices.

------------------------------------------------------------------------

## 2. Architecture Goals

### Primary goals

1.  **Clear separation of concerns**
2.  **Secure OAuth/JWT authentication**
3.  **Reliable GitHub integration**
4.  **Provider-independent AI orchestration**
5.  **Asynchronous execution for long-running AI missions**
6.  **Persistent mission and developer memory**
7.  **Caching and rate-limit protection**
8.  **Observable, auditable execution**
9.  **Idempotent background processing**
10. **Easy migration from modular monolith to services later**

### Key architectural decision

> FastAPI is the central application boundary. Domain modules
> communicate through application services and repositories rather than
> directly coupling to database tables or external providers.

------------------------------------------------------------------------

# 3. High-Level System Architecture

``` mermaid
flowchart TB
    U[Developer]

    subgraph CLIENT["Presentation Layer"]
        APP[Flutter Mobile / Web App]
        STATE[Riverpod State Management]
        ROUTER[GoRouter]
        UI[Material 3 + Glass UI]
    end

    subgraph EDGE["API & Security Layer"]
        API[FastAPI API]
        AUTH[Auth Middleware]
        RATE[Rate Limiter]
        VALID[Pydantic Validation]
    end

    subgraph APP_LAYER["Application / Domain Layer"]
        AUTH_S[Auth Service]
        DEV_S[Developer Intelligence]
        REPO_S[Repository Intelligence]
        ROAD_S[Roadmap Service]
        MENTOR_S[Mentor Service]
        REC_S[Recommendation Service]
        MISSION_S[Mission Orchestrator]
        MEMORY_S[Memory Service]
    end

    subgraph DATA["Data Layer"]
        PG[(PostgreSQL / Neon)]
        REDIS[(Redis)]
        STORAGE[(Supabase Storage)]
    end

    subgraph AI["AI Orchestration Layer"]
        AI_ADAPTER[LLM Provider Adapter]
        OPENAI[OpenAI]
        OLLAMA[Ollama]
        GEMINI[Gemini]
        NVIDIA[NVIDIA Model Fallback]
    end

    subgraph INT["External Integrations"]
        GH[GitHub REST / GraphQL]
        OAUTH[GitHub / Google OAuth]
        OPENCLAW[OpenClaw Gateway]
        COGNEE[Cognee Knowledge Graph]
        SKILLS[AutoDevs.dev + skills.sh]
    end

    U --> APP
    APP --> STATE
    APP --> ROUTER
    STATE --> API
    ROUTER --> API

    API --> AUTH
    AUTH --> RATE
    RATE --> VALID

    VALID --> AUTH_S
    VALID --> DEV_S
    VALID --> REPO_S
    VALID --> ROAD_S
    VALID --> MENTOR_S
    VALID --> REC_S
    VALID --> MISSION_S

    AUTH_S --> PG
    DEV_S --> PG
    REPO_S --> PG
    ROAD_S --> PG
    MENTOR_S --> PG
    REC_S --> PG
    MEMORY_S --> PG

    DEV_S --> REDIS
    REPO_S --> REDIS
    MISSION_S --> REDIS

    REPO_S --> GH
    AUTH_S --> OAUTH

    DEV_S --> AI_ADAPTER
    ROAD_S --> AI_ADAPTER
    MENTOR_S --> AI_ADAPTER
    REC_S --> AI_ADAPTER

    AI_ADAPTER --> OPENAI
    AI_ADAPTER --> OLLAMA

    MISSION_S --> OPENCLAW
    MISSION_S --> COGNEE
    MISSION_S --> SKILLS
    OPENCLAW --> GEMINI
    OPENCLAW --> NVIDIA

    STORAGE --> APP
```

------------------------------------------------------------------------

# 4. Four-Layer Architecture

Tatvik is organized into four major layers.

  -----------------------------------------------------------------------
  Layer                   Responsibility          Main Technologies
  ----------------------- ----------------------- -----------------------
  Presentation            UI, navigation, local   Flutter, Riverpod,
                          state, API consumption  GoRouter

  Application             API contracts,          FastAPI, Pydantic
                          orchestration, domain   
                          workflows               

  Domain/Data             Business logic,         Python services,
                          repositories,           SQLAlchemy, PostgreSQL
                          persistence             

  Integration             External APIs, AI       GitHub, OpenAI, Ollama,
                          providers, storage,     OpenClaw, Cognee, Redis
                          knowledge systems       
  -----------------------------------------------------------------------

The original architecture already defines these four layers and
identifies Flutter, FastAPI, PostgreSQL/Redis, and external integrations
as the core technology boundaries. fileciteturn0file0L3-L18

------------------------------------------------------------------------

# 5. Frontend Architecture

## 5.1 Flutter structure

``` text
lib/
├── core/
│   ├── config/
│   ├── constants/
│   ├── theme/
│   ├── networking/
│   ├── errors/
│   └── utils/
│
├── features/
│   ├── auth/
│   ├── onboarding/
│   ├── dashboard/
│   ├── analysis/
│   ├── repositories/
│   ├── roadmap/
│   ├── mentor/
│   ├── discover/
│   ├── command_center/
│   └── profile/
│
├── models/
├── services/
├── routes/
├── widgets/
└── main.dart
```

## 5.2 Frontend request flow

``` mermaid
flowchart LR
    SCREEN[Feature Screen]
    PROVIDER[Riverpod Provider]
    CLIENT[Typed API Client]
    API[FastAPI]
    MODEL[DTO / UI Model]
    STATE[Updated UI State]

    SCREEN --> PROVIDER
    PROVIDER --> CLIENT
    CLIENT --> API
    API --> CLIENT
    CLIENT --> MODEL
    MODEL --> STATE
    STATE --> SCREEN
```

### Responsibilities

-   Render all application screens.
-   Keep API models separate from presentation models.
-   Securely persist session metadata.
-   Handle loading, empty, error, retry, and offline states.
-   Keep feature modules independent.
-   Avoid placing business logic directly inside widgets.

------------------------------------------------------------------------

# 6. Backend Architecture

## 6.1 FastAPI structure

``` text
app/
├── main.py
│
├── api/
│   └── v1/
│       ├── router.py
│       └── endpoints/
│           ├── auth.py
│           ├── developers.py
│           ├── repositories.py
│           ├── analysis.py
│           ├── roadmap.py
│           ├── mentor.py
│           ├── recommendations.py
│           └── missions.py
│
├── core/
│   ├── config.py
│   ├── security.py
│   ├── logging.py
│   ├── rate_limit.py
│   └── dependencies.py
│
├── models/
├── schemas/
├── repositories/
├── services/
│   ├── auth/
│   ├── github/
│   ├── analysis/
│   ├── roadmap/
│   ├── mentor/
│   ├── recommendation/
│   ├── mission/
│   ├── memory/
│   └── ai/
│
├── integrations/
│   ├── github/
│   ├── openai/
│   ├── ollama/
│   ├── openclaw/
│   ├── cognee/
│   └── storage/
│
├── workers/
└── db/
    ├── session.py
    └── migrations/
```

The uploaded architecture already specifies FastAPI routers, core
configuration/security, database sessions, SQLAlchemy models, Pydantic
schemas, repositories, and services as the backend structure.
fileciteturn0file0L44-L54

------------------------------------------------------------------------

# 7. Backend Request Lifecycle

``` mermaid
sequenceDiagram
    participant F as Flutter
    participant A as FastAPI
    participant M as Middleware
    participant S as Service
    participant R as Repository
    participant C as Redis
    participant X as External API
    participant L as LLM

    F->>A: HTTPS request + JWT
    A->>M: Authenticate + validate + rate limit
    M->>S: Authorized request

    S->>C: Check cache

    alt Cache hit
        C-->>S: Cached response
    else Cache miss
        S->>R: Read/write domain data
        R->>X: External integration if required
        S->>L: AI inference if required
        L-->>S: Structured AI output
        S->>C: Cache result
    end

    S-->>A: Domain response
    A-->>F: Versioned JSON response
```

------------------------------------------------------------------------

# 8. Domain Modules

## 8.1 Authentication

Responsibilities:

-   GitHub OAuth
-   Google OAuth
-   Email authentication
-   JWT access tokens
-   Refresh tokens
-   Session management
-   User identity mapping
-   Authorization/RBAC preparation

## 8.2 Developer Intelligence

Consumes:

-   GitHub profile
-   Repository metadata
-   Languages
-   Commit history
-   Contributions
-   README/project quality
-   Developer-selected goals

Produces:

-   Developer profile
-   Skill fingerprint
-   Developer score
-   Strengths
-   Weaknesses
-   Skill gaps

## 8.3 Roadmap Engine

``` text
Developer Profile
       +
Skill Gaps
       +
Target Role
       +
Current Progress
       |
       v
Roadmap Generator
       |
       +--> Milestones
       +--> Topics
       +--> Projects
       +--> Timeline
       +--> Progress Tracking
```

## 8.4 Mentor Engine

The mentor service should use:

``` text
User Context
    +
Developer Profile
    +
Skill Gaps
    +
Roadmap
    +
Recent Progress
    +
Conversation History
    |
    v
Context Builder
    |
    v
LLM Provider
    |
    v
Structured Mentor Response
```

## 8.5 Recommendation Engine

Recommendations should be generated from:

-   Skill gaps
-   Target role
-   Current experience
-   Repository history
-   Difficulty
-   Learning value
-   Expected portfolio impact

------------------------------------------------------------------------

# 9. AI Architecture

## 9.1 Provider abstraction

All LLM calls should pass through one internal interface.

``` mermaid
flowchart TB
    S[Application Service]
    ORCH[AI Orchestrator]
    PROMPT[Prompt Template]
    GUARD[Guardrails]
    SCHEMA[Structured Output Schema]
    ROUTER[Model Router]

    OPENAI[OpenAI]
    OLLAMA[Ollama]
    GEMINI[Gemini]
    NVIDIA[NVIDIA Fallback]

    S --> ORCH
    ORCH --> PROMPT
    ORCH --> GUARD
    ORCH --> SCHEMA
    ORCH --> ROUTER

    ROUTER --> OPENAI
    ROUTER --> OLLAMA
    ROUTER --> GEMINI
    ROUTER --> NVIDIA
```

### Why this abstraction matters

The existing architecture already requires a provider abstraction so
prompt templates, guardrails, and output schemas remain consistent
between hosted and local inference providers.
fileciteturn0file0L77-L91

This should be treated as a hard architectural boundary.

------------------------------------------------------------------------

# 10. AI Reliability Pipeline

Every important AI request should follow:

``` text
Input
  |
  v
Context Builder
  |
  v
Prompt Template
  |
  v
Guardrails
  |
  v
Model Router
  |
  v
LLM
  |
  v
Schema Validation
  |
  +---- invalid ----> Retry / Repair
  |
  v
Persistence
  |
  v
Cache
  |
  v
API Response
```

### Required controls

-   Request timeout
-   Retry with bounded attempts
-   Rate limiting
-   Concurrency limiting
-   Circuit breaker
-   Response caching
-   Structured output validation
-   Provider fallback
-   Prompt/version tracking

The current implementation already includes concurrency limiting,
request spacing, circuit breaking, response caching, and model fallback
for Gemini-based mission execution. fileciteturn0file0L129-L138

------------------------------------------------------------------------

# 11. Command Center --- Mission-to-PR Architecture

The Command Center is the most important autonomous execution path.

``` mermaid
flowchart TB
    USER[Developer]
    APP[Flutter Command Center]

    CREATE[POST /api/v1/openclaw/missions]
    TRACKER[Mission Pipeline Tracker]

    CONTEXT[Repository Understanding]
    GH_TREE[GitHub Tree + Key Files]
    GRAPH[Cognee Knowledge Graph]
    SKILL[Developer Skills Fingerprint]

    PLAN[Requirement + Planning + Design]
    DEV[Development]
    TEST[Testing]
    REVIEW[Review]
    DEPLOY[Deployment]
    MEMORY[Memory]

    GATEWAY[OpenClaw Gateway]
    AGENT[AI Agent]
    MODEL[Gemini]
    FALLBACK[NVIDIA Fallback]

    CHANGE[Strict JSON Change Plan]
    BRANCH[Create Mission Branch]
    FILES[Write Files via GitHub API]
    PR[Create Pull Request]

    USER --> APP
    APP --> CREATE
    CREATE --> TRACKER

    TRACKER --> CONTEXT
    CONTEXT --> GH_TREE
    CONTEXT --> GRAPH
    CONTEXT --> SKILL

    CONTEXT --> PLAN
    PLAN --> GATEWAY
    GATEWAY --> AGENT
    AGENT --> MODEL
    MODEL --> DEV

    DEV --> TEST
    TEST --> REVIEW
    REVIEW --> DEPLOY
    DEPLOY --> MEMORY

    MEMORY --> CHANGE
    CHANGE --> BRANCH
    BRANCH --> FILES
    FILES --> PR
```

The current Command Center design uses eight logical
stages---Requirement, Planning, Design, Development, Testing, Review,
Deployment, and Memory---but batches them into three gateway dispatches
to reduce model/free-tier pressure. fileciteturn0file0L116-L127

------------------------------------------------------------------------

# 12. Mission State Machine

A mission should have an explicit state machine.

``` mermaid
stateDiagram-v2
    [*] --> CREATED
    CREATED --> UNDERSTANDING
    UNDERSTANDING --> PLANNING
    PLANNING --> DEVELOPMENT
    DEVELOPMENT --> TESTING
    TESTING --> REVIEW
    REVIEW --> PR_CREATION
    PR_CREATION --> COMPLETED

    TESTING --> FAILED
    DEVELOPMENT --> FAILED
    REVIEW --> FAILED
    UNDERSTANDING --> FAILED

    FAILED --> RETRYING
    RETRYING --> UNDERSTANDING

    COMPLETED --> MEMORY_UPDATED
    MEMORY_UPDATED --> [*]
```

This prevents ambiguous background-job states and makes the Command
Center observable.

------------------------------------------------------------------------

# 13. Repository Understanding Pipeline

``` mermaid
flowchart LR
    REPO[GitHub Repository]

    TREE[File Tree]
    README[README]
    KEY[Key Source Files]
    HISTORY[Commit / PR Signals]

    COG[Cognee Knowledge Graph]
    SKILLS[Developer Skills]
    FINGERPRINT[Stack Fingerprint]

    CONTEXT[Rendered Repository Context]

    REPO --> TREE
    REPO --> README
    REPO --> KEY
    REPO --> HISTORY

    TREE --> CONTEXT
    README --> CONTEXT
    KEY --> CONTEXT
    HISTORY --> CONTEXT

    COG --> CONTEXT
    SKILLS --> CONTEXT
    FINGERPRINT --> CONTEXT
```

The current implementation combines Cognee memory, the live GitHub file
tree, important files, README information, and a skills fingerprint into
a rendered context block before mission execution.
fileciteturn0file0L121-L127

------------------------------------------------------------------------

# 14. Data Architecture

## 14.1 Storage responsibilities

``` mermaid
flowchart TB
    APP[Application]

    PG[(PostgreSQL)]
    REDIS[(Redis)]
    SUPA[(Supabase Storage)]
    COG[(Cognee)]

    APP --> PG
    APP --> REDIS
    APP --> SUPA
    APP --> COG
```

### PostgreSQL --- source of truth

Store:

-   Users
-   OAuth identities
-   Developer profiles
-   Repository metadata
-   Analysis results
-   Skill gaps
-   Roadmaps
-   Roadmap progress
-   Recommendations
-   Mentor conversations
-   Missions
-   Mission stages
-   Pull requests
-   Audit events

The current architecture defines PostgreSQL/Neon as the source of truth
for users, profiles, scores, skill gaps, roadmaps, chats, and
recommendations. fileciteturn0file0L64-L74

### Redis

Use for:

-   API response caching
-   AI response caching
-   Rate limiting
-   Short-lived session/throttle state
-   Job coordination
-   Idempotency keys

### Supabase Storage

Use for:

-   Avatars
-   Attachments
-   Generated assets

### Cognee

Use as the knowledge/memory layer for:

-   Repository understanding
-   Previous mission context
-   Architecture memory
-   Developer/project knowledge

------------------------------------------------------------------------

# 15. Recommended Core Database Model

``` mermaid
erDiagram
    USER ||--o{ OAUTH_IDENTITY : has
    USER ||--|| DEVELOPER_PROFILE : owns
    USER ||--o{ REPOSITORY : connects
    USER ||--o{ ROADMAP : owns
    USER ||--o{ CHAT : starts
    USER ||--o{ MISSION : creates

    REPOSITORY ||--o{ ANALYSIS : receives
    DEVELOPER_PROFILE ||--o{ SKILL_GAP : has
    ROADMAP ||--o{ ROADMAP_ITEM : contains
    MISSION ||--o{ MISSION_STAGE : contains
    MISSION ||--o| PULL_REQUEST : produces

    USER {
        uuid id PK
        string email
        string display_name
        datetime created_at
        datetime updated_at
    }

    DEVELOPER_PROFILE {
        uuid id PK
        uuid user_id FK
        jsonb skill_profile
        float score
        string target_role
    }

    REPOSITORY {
        uuid id PK
        uuid user_id FK
        string github_id
        string full_name
        string default_branch
    }

    ANALYSIS {
        uuid id PK
        uuid repository_id FK
        jsonb result
        string model_version
    }

    SKILL_GAP {
        uuid id PK
        uuid profile_id FK
        string skill
        float gap_score
    }

    ROADMAP {
        uuid id PK
        uuid user_id FK
        string title
        string target_role
        string status
    }

    ROADMAP_ITEM {
        uuid id PK
        uuid roadmap_id FK
        string title
        string status
        int order_index
    }

    MISSION {
        uuid id PK
        uuid user_id FK
        string repository
        string status
        string current_stage
    }

    MISSION_STAGE {
        uuid id PK
        uuid mission_id FK
        string stage
        string status
        jsonb output
    }

    PULL_REQUEST {
        uuid id PK
        uuid mission_id FK
        string github_url
        string branch
        int number
    }
```

------------------------------------------------------------------------

# 16. Authentication Architecture

``` mermaid
sequenceDiagram
    participant U as User
    participant F as Flutter
    participant O as OAuth Provider
    participant A as FastAPI
    participant DB as PostgreSQL
    participant S as Secure Storage

    U->>F: Select Login
    F->>O: OAuth Authorization
    O-->>F: Authorization Result
    F->>A: OAuth callback/token
    A->>O: Validate identity
    A->>DB: Create/update user
    A-->>F: Access + Refresh Tokens
    F->>S: Store tokens securely
    F->>A: Authenticated API request
    A-->>F: Response
```

The current authentication flow already follows OAuth/email login →
backend validation → user creation/update → JWT issuance → secure client
storage → middleware verification. fileciteturn0file0L93-L99

------------------------------------------------------------------------

# 17. API Design

All public API routes should be versioned.

``` text
/api/v1/
├── auth/
├── users/
├── developers/
├── repositories/
├── analysis/
├── skills/
├── roadmaps/
├── recommendations/
├── mentor/
├── missions/
├── command-center/
└── health/
```

### Example mission API

``` http
POST /api/v1/openclaw/missions
```

``` json
{
  "title": "Add authentication",
  "description": "Implement GitHub OAuth for the application",
  "repository": "owner/repository",
  "execute": true
}
```

Response:

``` json
{
  "mission_id": "uuid",
  "status": "queued",
  "current_stage": "requirement"
}
```

Long-running execution should return quickly and continue
asynchronously.

------------------------------------------------------------------------

# 18. Asynchronous Mission Execution

Do not keep the HTTP request open while the AI agent performs repository
work.

``` mermaid
flowchart LR
    API[POST Mission]
    DB[(Mission DB)]
    QUEUE[Background Job / Queue]
    WORKER[Mission Worker]
    GATEWAY[OpenClaw]
    GH[GitHub]
    PR[Pull Request]

    API --> DB
    API --> QUEUE
    QUEUE --> WORKER
    WORKER --> GATEWAY
    WORKER --> GH
    GH --> PR
    WORKER --> DB
```

### Recommended implementation path

**Current phase:**

-   FastAPI background execution.
-   Redis for coordination/idempotency.
-   Explicit mission states.
-   Persist every stage transition.

**Scale phase:**

-   Move mission execution to dedicated workers.
-   Introduce a durable queue such as Celery/RQ/Arq or another selected
    worker platform.
-   Keep the API process stateless.

------------------------------------------------------------------------

# 19. GitHub Integration Boundary

GitHub should be accessed only through a dedicated adapter.

``` text
GitHubService
├── get_user()
├── list_repositories()
├── get_repository_tree()
├── get_file()
├── get_commits()
├── create_branch()
├── update_file()
├── create_commit()
└── create_pull_request()
```

This prevents GitHub-specific API details from leaking into domain
services.

------------------------------------------------------------------------

# 20. Mission → Pull Request Safety Boundary

The autonomous coding path should have a strict boundary:

``` text
User Mission
     |
     v
Repository Understanding
     |
     v
AI Plan
     |
     v
Schema Validation
     |
     v
Allowed File Changes
     |
     v
Sandbox / Test
     |
     v
Git Branch
     |
     v
Commit
     |
     v
Pull Request
```

### Important rule

> The AI should propose changes through a structured change plan. The
> backend, not the model, controls GitHub mutations.

This keeps credentials, branch creation, file writes, and PR creation
under deterministic application logic.

------------------------------------------------------------------------

# 21. Developer Skills Pipeline

``` mermaid
flowchart TB
    PROFILE[Developer Profile]
    AUTO[AutoDevs.dev Profiles]
    SH[skills.sh]
    LOCAL[.autodevs/prompts.md]

    REG[Developer Skills Registry]
    DETECT[Stack Detection]
    SELECT[Relevant Skills]
    CONTEXT[Mission Context]
    PLAN[Change Plan]

    PROFILE --> REG
    AUTO --> REG
    SH --> REG
    LOCAL --> REG

    REG --> DETECT
    DETECT --> SELECT
    SELECT --> CONTEXT
    CONTEXT --> PLAN
```

The current design loads skills from AutoDevs.dev profiles, skills.sh,
and `.autodevs/prompts.md`, then injects relevant skills into repository
context and change-plan generation. fileciteturn0file0L140-L147

------------------------------------------------------------------------

# 22. Caching Strategy

Use caching at three levels.

### Level 1 --- API cache

For read-heavy data:

``` text
GET developer profile
GET repository metadata
GET roadmap
GET recommendations
```

### Level 2 --- AI cache

Cache deterministic or repeatable AI requests using:

``` text
hash(
    provider +
    model +
    prompt_version +
    input_context
)
```

### Level 3 --- Repository cache

Cache:

-   GitHub file trees
-   README
-   Repository metadata
-   Commit summaries
-   Skills fingerprint

Invalidate repository caches after meaningful repository changes or on
explicit refresh.

------------------------------------------------------------------------

# 23. Observability

Every request should carry:

``` text
request_id
user_id
trace_id
endpoint
duration_ms
status_code
model
provider
tokens
cache_hit
mission_id
```

### Mission logs

Each mission stage should record:

``` text
mission_id
stage
attempt
started_at
completed_at
status
provider
model
latency
error
output_reference
```

The current architecture already calls for structured logging, request
IDs, health checks, and audit-friendly events.
fileciteturn0file0L13-L19

------------------------------------------------------------------------

# 24. Reliability & Failure Handling

``` mermaid
flowchart TB
    REQ[AI Request]
    LIMIT[Concurrency / Rate Guard]
    MODEL[Primary Model]
    RETRY[Bounded Retry]
    FALLBACK[Fallback Model]
    BREAKER[Circuit Breaker]
    ERROR[Graceful Error]
    CACHE[Response Cache]

    REQ --> CACHE

    CACHE -->|Miss| LIMIT
    LIMIT --> MODEL

    MODEL -->|Success| CACHE
    MODEL -->|429 / transient error| RETRY
    RETRY --> MODEL

    RETRY -->|Repeated failure| BREAKER
    BREAKER --> FALLBACK
    FALLBACK --> CACHE
    FALLBACK -->|Failure| ERROR
```

The uploaded architecture already defines Gemini concurrency limits,
minimum spacing, a circuit breaker, response caching, and fallback from
Gemini to Gemini Flash Lite and then NVIDIA.
fileciteturn0file0L129-L138

------------------------------------------------------------------------

# 25. Security Architecture

## Authentication

-   OAuth 2.0
-   JWT access tokens
-   Refresh tokens
-   Secure client-side storage

## Secrets

Never store:

``` text
GITHUB_CLIENT_SECRET
OPENAI_API_KEY
GEMINI_API_KEY
DATABASE_URL
REDIS_URL
SUPABASE_SERVICE_KEY
```

in source control.

## API protection

-   Request validation
-   Rate limiting
-   Authentication middleware
-   Authorization checks
-   CORS policy
-   Secure headers
-   Audit logging

## GitHub permissions

Request the minimum OAuth scopes required.

The AI worker should not receive unrestricted credentials directly.
GitHub mutations should occur through the controlled backend adapter.

------------------------------------------------------------------------

# 26. Deployment Architecture

``` mermaid
flowchart TB
    USER[Developer]

    CDN[Firebase Hosting / Web]
    MOBILE[Android / iOS]

    API[Railway - FastAPI]
    WORKER[Mission Worker]

    DB[(Neon PostgreSQL)]
    REDIS[(Managed Redis)]
    STORAGE[(Supabase Storage)]

    GH[GitHub]
    OPENCLAW[OpenClaw HF Space]
    AI[AI Providers]

    USER --> CDN
    USER --> MOBILE

    CDN --> API
    MOBILE --> API

    API --> DB
    API --> REDIS
    API --> STORAGE
    API --> GH
    API --> AI

    API --> WORKER
    WORKER --> REDIS
    WORKER --> DB
    WORKER --> GH
    WORKER --> OPENCLAW
    OPENCLAW --> AI
```

The current deployment plan uses Flutter/Firebase Hosting for web
preview, Railway for FastAPI, Neon for PostgreSQL, managed Redis,
Supabase Storage, and GitHub Actions for CI/CD.
fileciteturn0file0L108-L114

------------------------------------------------------------------------

# 27. CI/CD

``` mermaid
flowchart LR
    DEV[Developer]
    PR[Pull Request]
    CI[GitHub Actions]

    LINT[Lint]
    TEST[Test]
    SECURITY[Security Checks]
    BUILD[Build]
    DEPLOY[Deploy]

    DEV --> PR
    PR --> CI

    CI --> LINT
    LINT --> TEST
    TEST --> SECURITY
    SECURITY --> BUILD
    BUILD --> DEPLOY
```

### Minimum pipeline

1.  Formatting
2.  Static analysis
3.  Unit tests
4.  Integration tests
5.  Security/dependency checks
6.  Backend build
7.  Flutter build
8.  Deployment

------------------------------------------------------------------------

# 28. Recommended Repository Boundary

``` text
tatvik/
├── apps/
│   ├── mobile/
│   └── web/
│
├── backend/
│   ├── app/
│   ├── tests/
│   └── migrations/
│
├── workers/
│   └── mission-worker/
│
├── packages/
│   ├── api-contracts/
│   └── shared-schemas/
│
├── infrastructure/
│   ├── docker/
│   └── deployment/
│
├── docs/
│   ├── architecture.md
│   ├── api.md
│   └── mission-pipeline.md
│
└── .github/
    └── workflows/
```

For the immediate implementation, `workers/` can remain part of the
backend deployment. It becomes a separately deployed component only when
mission volume justifies it.

------------------------------------------------------------------------

# 29. Architectural Boundaries

The following boundaries should remain strict:

``` text
Flutter
  |
  | API only
  v
FastAPI
  |
  | Application services
  v
Domain
  |
  +--> Repository --> PostgreSQL
  |
  +--> Integration Adapter --> External APIs
  |
  +--> AI Adapter --> LLM Providers
```

### Avoid

``` text
Flutter --> PostgreSQL
Flutter --> GitHub API directly
Domain Service --> raw SQL everywhere
Domain Service --> OpenAI SDK directly
LLM --> GitHub credentials directly
```

These shortcuts make testing, security, and future scaling harder.

------------------------------------------------------------------------

# 30. Implementation Roadmap

## Phase 1 --- Foundation

-   [ ] Flutter shell
-   [ ] FastAPI application
-   [ ] PostgreSQL/Neon
-   [ ] Redis
-   [ ] Environment configuration
-   [ ] CI pipeline
-   [ ] Health endpoint
-   [ ] Structured logging

## Phase 2 --- Identity

-   [ ] GitHub OAuth
-   [ ] Google OAuth
-   [ ] Email authentication
-   [ ] JWT access/refresh flow
-   [ ] Secure token storage
-   [ ] User/profile models

## Phase 3 --- Developer Intelligence

-   [ ] GitHub adapter
-   [ ] Repository synchronization
-   [ ] Repository analysis
-   [ ] Skill fingerprint
-   [ ] Developer score
-   [ ] Skill-gap engine

## Phase 4 --- Personalization

-   [ ] Roadmap engine
-   [ ] Recommendation engine
-   [ ] Mentor context builder
-   [ ] Conversation persistence
-   [ ] Progress tracking

## Phase 5 --- AI Platform

-   [ ] AI provider interface
-   [ ] Prompt registry
-   [ ] Structured outputs
-   [ ] Retry policy
-   [ ] Model fallback
-   [ ] AI caching
-   [ ] Token/cost tracking

## Phase 6 --- Command Center

-   [ ] Mission creation API
-   [ ] Mission state machine
-   [ ] Repository understanding
-   [ ] Cognee integration
-   [ ] Developer skills registry
-   [ ] OpenClaw gateway integration
-   [ ] Change-plan generation
-   [ ] GitHub branch creation
-   [ ] File mutation
-   [ ] Automated PR creation

## Phase 7 --- Reliability

-   [ ] Durable worker queue
-   [ ] Idempotency
-   [ ] Mission retries
-   [ ] Dead-letter handling
-   [ ] Distributed tracing
-   [ ] Alerting
-   [ ] Audit logs

## Phase 8 --- Scale

Only after actual load requires it:

``` text
Modular Monolith
      |
      +--> Mission Worker
      |
      +--> AI Worker
      |
      +--> Ingestion Worker
```

Do not split the entire backend into microservices prematurely.

------------------------------------------------------------------------

# 31. Final Architecture

``` mermaid
flowchart TB
    USER[Developer]

    subgraph CLIENT["Flutter Client"]
        UI[Material 3 + Glass UI]
        RIVER[Riverpod]
        ROUTE[GoRouter]
    end

    subgraph API["Tatvik Backend"]
        GATE[FastAPI API]
        SEC[Auth + Validation + Rate Limit]

        subgraph DOMAIN["Bounded Contexts"]
            DEV[Developer Intelligence]
            REPO[Repository Intelligence]
            ROAD[Roadmap]
            MENTOR[Mentor]
            REC[Recommendations]
            MISSION[Command Center]
        end

        AIORCH[AI Orchestrator]
        MEMORY[Memory Service]
    end

    subgraph DATA["State & Persistence"]
        PG[(PostgreSQL)]
        REDIS[(Redis)]
        STORE[(Supabase Storage)]
    end

    subgraph KNOWLEDGE["Knowledge"]
        COG[Cognee]
        SKILL[Developer Skills Registry]
    end

    subgraph EXTERNAL["External Systems"]
        GITHUB[GitHub]
        OPENCLAW[OpenClaw Gateway]
        MODELS[OpenAI / Ollama / Gemini / NVIDIA]
    end

    USER --> UI
    UI --> RIVER
    RIVER --> ROUTE
    ROUTE --> GATE

    GATE --> SEC
    SEC --> DEV
    SEC --> REPO
    SEC --> ROAD
    SEC --> MENTOR
    SEC --> REC
    SEC --> MISSION

    DEV --> AIORCH
    ROAD --> AIORCH
    MENTOR --> AIORCH
    REC --> AIORCH

    AIORCH --> MODELS

    DEV --> PG
    REPO --> PG
    ROAD --> PG
    MENTOR --> PG
    REC --> PG
    MISSION --> PG

    DEV --> REDIS
    REPO --> REDIS
    MISSION --> REDIS

    REPO --> GITHUB
    MISSION --> GITHUB
    MISSION --> OPENCLAW

    MISSION --> COG
    MISSION --> SKILL
    MEMORY --> COG

    GATE --> STORE
```

------------------------------------------------------------------------

# 32. Architecture Decision Summary

  -----------------------------------------------------------------------
  Decision                Choice                  Reason
  ----------------------- ----------------------- -----------------------
  Backend style           Modular monolith        Faster development +
                                                  clean boundaries

  API                     FastAPI                 Typed, async-friendly,
                                                  Python AI ecosystem

  Client                  Flutter                 Mobile-first
                                                  cross-platform
                                                  experience

  State                   Riverpod                Testable feature-level
                                                  state

  Routing                 GoRouter                Route guards and deep
                                                  linking

  Database                PostgreSQL              Relational source of
                                                  truth

  Cache                   Redis                   Fast cache/rate
                                                  limiting/coordination

  Storage                 Supabase Storage        Assets and attachments

  AI                      Provider abstraction    Avoid provider lock-in

  Repository intelligence GitHub adapter          Isolate external API

  Knowledge               Cognee                  Repository and mission
                                                  memory

  Agent gateway           OpenClaw                Autonomous mission
                                                  execution

  Background work         Worker-based evolution  Avoid blocking API

  CI/CD                   GitHub Actions          Automated quality and
                                                  deployment

  Scaling strategy        Extract workers first   Lower complexity than
                                                  early microservices
  -----------------------------------------------------------------------

------------------------------------------------------------------------

# 33. Key Architectural Principle

> **Tatvik should be deterministic at the control plane and
> probabilistic only at the intelligence plane.**

The AI may decide:

-   what to analyze,
-   what skills are missing,
-   what roadmap to recommend,
-   what code changes to propose.

The application must decide:

-   who is authenticated,
-   what data can be accessed,
-   what files may be changed,
-   which GitHub operations are allowed,
-   how missions transition between states,
-   when retries happen,
-   when an AI provider is unavailable,
-   and whether a generated change can become a real pull request.

This separation is the core safety, reliability, and scalability
boundary of the architecture.
