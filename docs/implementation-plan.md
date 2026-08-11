# Tatvik Implementation Plan

## Objective
Build a production-grade Flutter application backed by FastAPI and PostgreSQL that can analyze GitHub activity, recommend repositories and projects, generate career roadmaps, and provide AI mentorship.

## Delivery Strategy
The project should be delivered in layers:
1. **Foundation** — design system, routing, auth scaffolding, environment configuration.
2. **Data ingestion** — GitHub integration, storage models, and caching.
3. **Intelligence layer** — developer scoring, skill gaps, roadmap generation, recommendations.
4. **Experience layer** — mentor chat, discovery flows, polished UX, and notifications.
5. **Hardening** — tests, observability, rate limiting, deployment, and release prep.

---

## Backend Implementation Plan

### 1. Project Bootstrap
- Create `backend/` with FastAPI app structure.
- Add dependency management, linting, formatting, and test tooling.
- Configure environment loading with Pydantic settings.
- Set up database session management and migrations.

### 2. Core Infrastructure
- Implement centralized logging with structured JSON logs.
- Add error handling middleware and standard API error responses.
- Add Redis integration for caching and rate limiting.
- Add security helpers for hashing, token generation, and JWT validation.

### 3. Authentication and User Management
- Implement GitHub OAuth flow.
- Implement Google OAuth flow.
- Implement email login and registration.
- Issue JWT access and refresh tokens.
- Support session refresh and logout.
- Support user profile creation and provider linking.

### 4. GitHub Data Integration
- Build REST and GraphQL clients for GitHub.
- Fetch profile, repositories, contribution history, languages, and topics.
- Normalize raw GitHub data into internal schemas.
- Store snapshots to reduce repeated API calls.

### 5. Analysis and Intelligence Services
- Build developer score calculator.
- Create skill gap detector.
- Create repository complexity and README quality scoring.
- Create roadmap generator.
- Create project and repository recommender.
- Create mentor response orchestrator.

### 6. API Layer
- Expose versioned REST endpoints under `/api/v1`.
- Use request/response Pydantic models for all routes.
- Separate routers by bounded context.
- Include pagination, sorting, and filtering for list endpoints.

### 7. Background Jobs and Observability
- Add job processing for heavy analysis tasks.
- Add health checks and readiness endpoints.
- Add request tracing and timing metrics.
- Add audit logging for analysis runs and recommendation generation.

### 8. Quality and Deployment
- Add unit and integration tests.
- Add OpenAPI documentation and example payloads.
- Containerize backend for Railway deployment.
- Configure environment variables and secrets management.

---

## Frontend Implementation Plan

### 1. Flutter Foundation
- Use Flutter with Material 3.
- Replace prototype state with Riverpod-based feature state.
- Set up GoRouter for all screens and guarded routes.
- Introduce a centralized theme and design token system.
- Build reusable glassmorphism widgets.

### 2. Authentication Experience
- Build splash, onboarding, login, and account recovery flows.
- Support OAuth and email auth entry points.
- Handle token storage and session restoration.
- Show loading, error, and retry states.

### 3. Dashboard and Analysis Views
- Build the main developer dashboard.
- Render score cards, charts, heatmaps, top repos, and AI insights.
- Add profile summary and growth trends.
- Support skeleton loading and empty states.

### 4. Discovery and Recommendations
- Build repository discovery filters and ranked lists.
- Build repository detail pages with learning reasons and time estimates.
- Build project recommendation surfaces for portfolio planning.

### 5. Roadmap and Mentor Experience
- Build roadmap timeline and milestone progression UI.
- Build mentor chat with message grouping, context chips, and prompt suggestions.
- Add history, bookmarks, and suggested questions.

### 6. Settings and Notifications
- Build account and preferences screens.
- Add notification controls and progress preferences.
- Add sign-out, cache reset, and privacy options.

### 7. Quality and Release
- Add widget tests for reusable UI components.
- Add golden tests for critical screens.
- Validate responsive behavior on mobile and tablet.
- Prepare release builds and app store metadata.

---

## Tasks Breakdown

### Foundation Tasks
- [ ] Create backend and frontend folder structures.
- [ ] Finalize environment variable templates.
- [ ] Build app theme tokens and typography scale.
- [ ] Set up routing and navigation guards.

### Auth Tasks
- [ ] Implement OAuth callback handling.
- [ ] Implement JWT issuance and refresh flow.
- [ ] Implement secure storage on the Flutter side.
- [ ] Add session expiry and logout handling.

### GitHub Tasks
- [ ] Connect GitHub REST API.
- [ ] Connect GitHub GraphQL API.
- [ ] Build repository and contribution ingestion pipelines.
- [ ] Persist GitHub profile snapshots.

### Intelligence Tasks
- [ ] Build developer score algorithm.
- [ ] Implement skill extraction and normalization.
- [ ] Implement skill gap scoring.
- [ ] Implement roadmap generation logic.
- [ ] Implement recommendation ranking.
- [ ] Implement mentor chat orchestration.

### UI Tasks
- [ ] Build splash screen.
- [ ] Build onboarding flow.
- [ ] Build login screen.
- [ ] Build dashboard screen.
- [ ] Build analysis screen.
- [ ] Build repository discovery and detail screens.
- [ ] Build roadmap screen.
- [ ] Build mentor chat screen.
- [ ] Build profile, settings, and notification screens.

### Quality Tasks
- [ ] Add backend tests for services and repositories.
- [ ] Add frontend widget tests.
- [ ] Add API contract checks.
- [ ] Add logging and error observability.
- [ ] Add CI/CD pipelines.
- [ ] Perform performance and security review.

---

## UI Screen Breakdown

### 1. Splash Screen
**Purpose:** app boot and session restore.

**Elements**
- Logo / brand mark
- Loading indicator
- Session validation state

### 2. Onboarding
**Purpose:** explain value proposition and collect intent.

**Elements**
- Carousel cards
- Feature highlights
- CTA to login

### 3. Login Screen
**Purpose:** authentication entry point.

**Elements**
- GitHub login button
- Google login button
- Email login form
- Terms and privacy links

### 4. Dashboard
**Purpose:** main home for growth overview.

**Elements**
- Developer score card
- Contribution stats
- Heatmap widget
- AI insights panel
- Top repositories

### 5. Profile
**Purpose:** show account and public GitHub summary.

**Elements**
- Avatar and identity card
- Connected providers
- Skill summary
- Edit / preferences entry points

### 6. GitHub Analysis
**Purpose:** expose analysis details and trends.

**Elements**
- Repository breakdown
- Commit trends
- Language distribution
- README quality cards
- Complexity insights

### 7. Repository Discovery
**Purpose:** discover learning-focused repositories.

**Elements**
- Search bar
- Filters and chips
- Ranked repository cards
- Recommendation rationale

### 8. Repository Details
**Purpose:** explain why a repo matters.

**Elements**
- Overview section
- Difficulty and time estimate
- Learning outcomes
- Related skills
- CTA actions

### 9. AI Mentor
**Purpose:** conversational guidance.

**Elements**
- Chat thread
- Suggested prompts
- Typing indicator
- Context cards

### 10. Career Roadmap
**Purpose:** structured learning journey.

**Elements**
- Timeline or stepper
- Milestones
- Progress completion state
- Skill targets

### 11. Project Recommendations
**Purpose:** project ideas for portfolio and career growth.

**Elements**
- Ranked idea cards
- Tags for category and difficulty
- Impact/effort indicators
- Save / dismiss actions

### 12. Settings
**Purpose:** app and account controls.

**Elements**
- Theme and notification toggles
- Account actions
- Privacy and data controls
- Sign out

### 13. Notifications
**Purpose:** progress and insight alerts.

**Elements**
- Notification feed
- Unread states
- Filter tabs
- Mark-as-read actions

---

## Week-Wise Development Roadmap

### Week 1 — Project Setup
- Bootstrap Flutter and FastAPI projects.
- Implement design tokens and glass cards.
- Build splash, onboarding, and login UI.

### Week 2 — GitHub Integration
- Implement GitHub OAuth.
- Integrate GitHub REST and GraphQL clients.
- Populate dashboard with real data.

### Week 3 — Analysis Engine
- Build developer analysis services.
- Implement skill gap detection.
- Persist analysis outputs.

### Week 4 — Repository Recommendation Engine
- Build repository ranking and filtering.
- Add learning reasons and time estimates.
- Build repository details view.

### Week 5 — Career Roadmap
- Build roadmap generator.
- Add milestone tracking and completion actions.
- Create roadmap visualization UI.

### Week 6 — AI Mentor Chat
- Add chat orchestration.
- Add prompt suggestions and history.
- Handle contextual answers from the backend.

### Week 7 — Open Source Assistant
- Add issue discovery and explanation flows.
- Add contribution guidance and next-step actions.

### Week 8 — Testing, Optimization, Deployment
- Add automated tests.
- Optimize caching and performance.
- Prepare deployment, analytics, and store release assets.

