# DevMentor - Completed Progress Report & Architecture

DevMentor is a premium, high-fidelity developer mentoring and growth-coaching application. This document summarizes all features, designs, database schemas, and AI services completed and integrated to date.

---

## 🚀 Key Features Completed

### 1. Visual Design & UI System (Apple/iOS Glassmorphism)
* **Obsidian & White Glassmorphism**: Custom glass-blur cards with linear gradient borders that stand out clearly in dark and light modes.
* **Vibrant Fluid Background**: Beautiful, blurred background radial gradient orbs (Mint, Lavender, Sky Blue) that blend smoothly on both light and dark backgrounds.
* **Instant Theme Selector**: A theme switcher button built directly into the welcome header of the Home screen for quick toggling between High-Contrast Dark and Light mode.
* **iOS Pill Navigation**: A sleek floating bottom navigation bar that anchors all main views: Home, Explore, Roadmap, and Settings.

### 2. Year-Wise Horizontally Scrollable Heatmap & Activity Tooltips
* **Year Picker Dropdown**: Allows filtering activity by "Last 14 Weeks" or specific calendar years (e.g. 2026, 2025, 2024, 2023).
* **Weekly Horizontal Scrolling**: Switches to a 53-week (columns) by 7-day (rows) layout when a year is selected, allowing detailed tracking without UI overflow.
* **Interactive Day Activity popups**: When tapping on any cell in the heatmap, a dialog asynchronously queries the backend to fetch the exact contributions for that day.
* **GitHub GraphQL Integration**: Communicates directly with GitHub's GraphQL API to request the `contributionsCollection` for that day, showing the exact repositories committed to, PRs opened, issues filed, and code reviews submitted.

### 3. AI Mentor Chatbot (Double-Engine: Groq + Gemini)
* **High-Speed Groq Engine**: Uses Groq's `llama-3.1-8b-instant` model as the primary chat engine for sub-second, highly engaging responses.
* **Gemini fallback**: Automatically falls back to Gemini `gemini-2.5-flash` if Groq credentials are not present.
* **Growth Guardrails**: Programmed to decline general knowledge or coding requests unrelated to career coaching, steering users back to their growth journey.
* **Short Plaintext Outputs**: Explicitly formatted at the prompt and post-processing level to remove markdown bolding (`**`) and headers (`#`), returning short, punchy plaintext.

### 4. 24/7 Tech News RSS Background Scanner
* **Background Worker**: Starts an asynchronous background task on FastAPI startup that fetches, parses, and caches tech articles every hour.
* **RSS Source Integrations**: Dynamically parses RSS feeds from Hacker News and TechCrunch without requiring external XML parsing libraries.
* **AI News-Driven Mentoring**: Integrates these real-time cached news headlines into the chatbot's system prompt, allowing the AI to recommend modern technologies to learn based on actual daily trends.

### 5. GitHub OAuth Integration & Score Calculation
* **Secure Flow Callback**: Redirects the authorization code to the backend callback (`/api/v1/auth/github/callback`), exchanges it for a user access token, syncs repositories, and logs the user in.
* **Developer Score**: Dynamically calculates a user's developer rating out of 10.0 based on stargazers count, repository counts, and commits, syncing it to the local SQLite database.

### 6. Killer Portfolio Features (10 Advanced Upgrades)
* **Developer DNA Engine**: Automatically categorizes developers into distinct archetypes (🚀 Builder, 🧠 Architect, ⚡ Hacker, 🌎 Explorer) based on repository data, showcasing an alignment score, strengths, and weaknesses.
* **AI Resume Reviewer**: Compares a developer's pasted resume text against synced GitHub projects, calculating an ATS score, calling out missing technologies, and recommending bullet point upgrades.
* **AI Project Evaluator**: Scores a user's proposed project idea out of 10.0 and generates a detailed, cloud-native 4-step premium upgrade path (incorporating OAuth, Caching, Docker, CI/CD, and Monitoring).
* **Open Source Copilot**: Helps users breakdown complex open-source issues by explaining the issue, tracing codebase structure, listing files to focus on, and producing a comprehensive step-by-step implementation plan.
* **Duolingo-Style Learning Paths**: Generates 5-step custom open-source learning paths recommending real repositories to study, descriptions, and learning tasks, tracking completion state.
* **Developer Battle Mode**: Compares the developer's profile against templates (e.g. Senior Backend Engineer) to score matching alignment and identify critical skills to acquire.
* **AI Weekly Growth Report**: Shows Mon-Sun activity commit graphs with explored repository count, new skills learned count, and percentage growth.
* **GitHub Profile Roast**: Delivers a brutal, funny, and viral profile roast based on repository quality, incomplete descriptions, and lack of READMEs, along with constructive profile tips.
* **Opportunity Scanner**: Recommends forward-looking projects to build this week based on real-time RSS scanned headlines.
* **Personal Developer Memory**: Persists the user's career goals and preferred tech stacks in settings to tailor all AI recommender outputs.

---

## 📁 Key File Map

### Frontend (Flutter Web)
* [lib/main.dart](file:///home/heet18/Projects/devmentor/lib/main.dart): Entrypoint initializing application states and routes.
* [lib/providers/app_state.dart](file:///home/heet18/Projects/devmentor/lib/providers/app_state.dart): State container managing theme toggling, chat histories, repositories, contribution data fetching, and advanced feature requests.
* [lib/screens/home/home_screen.dart](file:///home/heet18/Projects/devmentor/lib/screens/home/home_screen.dart): Renders the main dashboard, Developer DNA, Weekly Growth Report, profile roasts, score metrics, the clickable heatmap grid, and the theme switcher.
* [lib/screens/repositories/discover_repos_screen.dart](file:///home/heet18/Projects/devmentor/lib/screens/repositories/discover_repos_screen.dart): Explores repositories, reviews resumes, evaluates projects, and scans opportunities.
* [lib/screens/roadmap/roadmap_screen.dart](file:///home/heet18/Projects/devmentor/lib/screens/roadmap/roadmap_screen.dart): Traces milestones, learning paths, developer battle mode, and open-source copilot blueprints.
* [lib/screens/profile/profile_screen.dart](file:///home/heet18/Projects/devmentor/lib/screens/profile/profile_screen.dart): Stores developer goals and tech stacks to personalize AI recommendation engines.
* [lib/core/theme/app_theme.dart](file:///home/heet18/Projects/devmentor/lib/core/theme/app_theme.dart): High-contrast colors, text themes, and solid card structures for maximum accessibility.

### Backend (FastAPI)
* [backend/app/main.py](file:///home/heet18/Projects/devmentor/backend/app/main.py): Sets up ASGI application, CORS middleware, and spawns the 24/7 RSS periodic tech news RSS scanner task.
* [backend/app/services/news_scanner.py](file:///home/heet18/Projects/devmentor/backend/app/services/news_scanner.py): Asynchronous feed fetcher and parsing logic.
* [backend/app/api/v1/endpoints/advanced.py](file:///home/heet18/Projects/devmentor/backend/app/api/v1/endpoints/advanced.py): Houses endpoints for developer archetypes, profile roasts, resume matching, project values, skill battlegrounds, and open-source issue copilots.
* [backend/app/api/v1/endpoints/github.py](file:///home/heet18/Projects/devmentor/backend/app/api/v1/endpoints/github.py): Serves year-wise contribution arrays and daily activity lists using GitHub GraphQL.
* [backend/app/api/v1/endpoints/mentor.py](file:///home/heet18/Projects/devmentor/backend/app/api/v1/endpoints/mentor.py): Standard AI mentor chat router integrating Groq, Gemini, and real-time tech news injection.
* [backend/app/api/v1/endpoints/roadmap.py](file:///home/heet18/Projects/devmentor/backend/app/api/v1/endpoints/roadmap.py): Employs JSON response modes in the LLMs to construct custom 5-milestone career roadmaps based on repositories.

---

## 🛠️ Running Services

* **Frontend Web App**: Serving at [http://localhost:8080](http://localhost:8080)
* **Backend API Server**: Serving at [http://127.0.0.1:8000](http://127.0.0.1:8000)
