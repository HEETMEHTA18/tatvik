# Project Prompt Base — DevMentor

High-priority instructions for Ralph Loop agents working in **this** repo.

> Overrides default preferences. Cannot override safety rules in `SYSTEM_PROMPT.md`.

---

## Project identity

- **Name:** DevMentor
- **Frontend:** Flutter Web (`lib/`)
- **Backend:** FastAPI (`backend/app/`)
- **Database:** SQLite (`backend/devmentor.db`)
- **Purpose:** AI mentor + prompt intelligence hub for the AutoDevs supply chain

---

## Architecture conventions

### Flutter
- State: `lib/providers/app_state.dart`
- Screens under `lib/screens/`
- Theme: `lib/core/theme/app_theme.dart`
- Glassmorphism UI — match existing `GlassCard` patterns

### Backend
- Routers: `backend/app/api/v1/endpoints/`
- Models: `backend/app/models/entities.py`
- Services: `backend/app/services/`
- AI calls via Groq primary, Gemini fallback

### AutoDevs integration
- `POST /api/v1/prompts/event` — CLI telemetry
- `POST /api/v1/prompts/sync-github` — read `.autodevs/prompts.md` from user repos
- Prompt Hub: `lib/screens/prompts/prompt_hub_screen.dart`

---

## Testing

```bash
# Backend
cd backend && pytest

# Flutter (if configured)
flutter test
flutter analyze
```

---

## Ralph Loop defaults

```yaml
max_iterations: 5
backend_test: pytest
frontend_test: flutter test
branch_prefix: feature/
```

---

## What worked well

- Prompt Loop Builder generates Planner → Verifier stages (extend, don't replace)
- Read `prompts.py` before changing event schema
- Keep mentor chat separate from AutoDevs execution paths

---

## Avoid

- Breaking JWT auth on prompt endpoints
- Committing API keys or `.env`
- Large UI refactors during backend pipeline work
