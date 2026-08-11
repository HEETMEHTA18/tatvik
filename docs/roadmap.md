# Tatvik Project Roadmap

## Overview
This roadmap covers the first 8 weeks of execution for Tatvik, with each week focused on a shippable milestone.

## Week 1 — Foundation and UI System
**Goal:** establish the app shell, design system, and authentication entry points.

**Work Items**
- Set up Flutter project structure.
- Set up FastAPI project scaffolding.
- Define environment variables and configuration files.
- Implement the dark glassmorphism theme.
- Build splash, onboarding, and login screens.
- Wire GoRouter navigation and route guards.

**Deliverable**
- A polished UI shell with auth entry flow and reusable design tokens.

**Acceptance Criteria**
- App launches cleanly.
- Routes resolve correctly.
- Core visual system is consistent across screens.

## Week 2 — GitHub Integration
**Goal:** connect user identity and GitHub data.

**Work Items**
- Implement GitHub OAuth.
- Implement GitHub profile sync.
- Add repository ingestion and normalization.
- Add dashboard sections driven by real data.

**Deliverable**
- Authenticated users can connect GitHub and see real profile data.

**Acceptance Criteria**
- OAuth session persists.
- GitHub data appears on dashboard.
- API errors are handled gracefully.

## Week 3 — Analysis Engine
**Goal:** transform raw GitHub data into actionable insights.

**Work Items**
- Build developer score logic.
- Add commit, language, and README analysis.
- Detect strengths and skill gaps.
- Persist analysis snapshots.

**Deliverable**
- A first version of the developer intelligence engine.

**Acceptance Criteria**
- Score and skill gap results are reproducible.
- Analysis data is stored historically.

## Week 4 — Repository Discovery Engine
**Goal:** recommend repositories and learning resources.

**Work Items**
- Rank repositories by learning relevance.
- Add difficulty and time estimates.
- Build discovery list, filters, and repository detail views.

**Deliverable**
- A usable discovery experience with clear recommendation reasoning.

**Acceptance Criteria**
- Repositories are explainable and sortable.
- Detail pages provide actionable learning context.

## Week 5 — Career Roadmap
**Goal:** generate a personalized learning path.

**Work Items**
- Generate roadmap milestones from skill gaps.
- Visualize progression and completion.
- Add milestone notes and progress metrics.

**Deliverable**
- A personalized roadmap that users can track over time.

**Acceptance Criteria**
- Roadmap updates reflect backend state.
- Progress is visible and understandable.

## Week 6 — AI Mentor Chat
**Goal:** introduce conversational coaching.

**Work Items**
- Build chat UI.
- Integrate AI response generation.
- Add prompt suggestions and history.
- Carry user context into responses.

**Deliverable**
- AI mentor available inside the app.

**Acceptance Criteria**
- Messages are persisted.
- Responses are contextual.
- Error and retry states are clear.

## Week 7 — Open Source Assistant
**Goal:** help users contribute to open source with confidence.

**Work Items**
- Discover beginner-friendly issues.
- Explain issue requirements.
- Provide contribution steps and checklists.

**Deliverable**
- A contribution assistant that turns issues into action plans.

**Acceptance Criteria**
- Issue recommendations are understandable.
- Guidance adapts to the user profile.

## Week 8 — Testing, Optimization, and Release Prep
**Goal:** harden the product and prepare for launch.

**Work Items**
- Add backend and frontend tests.
- Add caching and rate limiting verification.
- Improve loading states, empty states, and error states.
- Prepare deployment pipelines and release assets.

**Deliverable**
- A production-ready MVP suitable for beta release.

**Acceptance Criteria**
- Core flows are stable.
- Performance is acceptable.
- Deployment configuration is complete.

## Release Milestones
- **M1:** UI foundation complete
- **M2:** GitHub integration live
- **M3:** Analysis and roadmap generation live
- **M4:** Mentor and discovery flows live
- **M5:** Beta-ready hardening complete
