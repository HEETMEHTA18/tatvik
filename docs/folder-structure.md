# Project Folder Structure

## Target Repository Layout

```text
tatvik/
├── android/
├── ios/
├── linux/
├── macos/
├── web/
├── windows/
├── lib/
├── backend/
├── docs/
├── test/
├── analysis_options.yaml
├── pubspec.yaml
├── README.md
└── .github/
```

## Flutter Frontend Structure

```text
lib/
├── core/
│   ├── config/
│   │   ├── app_config.dart
│   │   ├── env.dart
│   │   └── constants.dart
│   ├── theme/
│   │   ├── app_theme.dart
│   │   ├── color_tokens.dart
│   │   ├── typography.dart
│   │   └── spacing.dart
│   └── utils/
│       ├── formatters.dart
│       ├── validators.dart
│       └── logger.dart
├── features/
│   ├── auth/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── dashboard/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── analysis/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── repositories/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── roadmap/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── mentor/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── discover/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   └── profile/
│       ├── data/
│       ├── domain/
│       └── presentation/
├── services/
│   ├── api_client.dart
│   ├── auth_service.dart
│   ├── github_service.dart
│   ├── mentor_service.dart
│   └── storage_service.dart
├── models/
│   ├── user_model.dart
│   ├── repository_model.dart
│   ├── analysis_model.dart
│   ├── roadmap_model.dart
│   └── mentor_message.dart
├── routes/
│   ├── app_router.dart
│   ├── route_paths.dart
│   └── route_guards.dart
├── widgets/
│   ├── glass_card.dart
│   ├── primary_button.dart
│   ├── stat_tile.dart
│   ├── section_header.dart
│   └── empty_state.dart
└── main.dart
```

## Backend Structure

```text
backend/
├── app/
│   ├── api/
│   │   ├── deps.py
│   │   ├── router.py
│   │   └── v1/
│   │       ├── endpoints/
│   │       │   ├── auth.py
│   │       │   ├── users.py
│   │       │   ├── github.py
│   │       │   ├── repositories.py
│   │       │   ├── analysis.py
│   │       │   ├── roadmap.py
│   │       │   ├── mentor.py
│   │       │   └── recommendations.py
│   │       └── api.py
│   ├── core/
│   │   ├── config.py
│   │   ├── security.py
│   │   ├── logging.py
│   │   ├── rate_limiter.py
│   │   └── exceptions.py
│   ├── db/
│   │   ├── base.py
│   │   ├── session.py
│   │   └── migrations/
│   ├── models/
│   │   ├── user.py
│   │   ├── github_profile.py
│   │   ├── repository.py
│   │   ├── developer_score.py
│   │   ├── skill.py
│   │   ├── skill_gap.py
│   │   ├── roadmap.py
│   │   ├── recommendation.py
│   │   ├── mentor_chat.py
│   │   └── project_recommendation.py
│   ├── schemas/
│   │   ├── auth.py
│   │   ├── user.py
│   │   ├── github.py
│   │   ├── analysis.py
│   │   ├── roadmap.py
│   │   ├── mentor.py
│   │   └── recommendations.py
│   ├── repositories/
│   │   ├── base.py
│   │   ├── user_repository.py
│   │   ├── analysis_repository.py
│   │   ├── roadmap_repository.py
│   │   └── recommendation_repository.py
│   ├── services/
│   │   ├── auth_service.py
│   │   ├── github_service.py
│   │   ├── analysis_service.py
│   │   ├── roadmap_service.py
│   │   ├── mentor_service.py
│   │   ├── recommendation_service.py
│   │   └── ai/
│   │       ├── provider.py
│   │       ├── openai_provider.py
│   │       └── ollama_provider.py
│   ├── utils/
│   │   ├── pagination.py
│   │   ├── serializers.py
│   │   └── time.py
│   └── main.py
├── tests/
├── alembic/
├── pyproject.toml
└── Dockerfile
```

## Infra and Operations

```text
.github/
├── workflows/
│   ├── flutter-ci.yml
│   ├── backend-ci.yml
│   └── deploy.yml
├── ISSUE_TEMPLATE/
└── PULL_REQUEST_TEMPLATE.md

scripts/
├── seed_database.py
├── generate_openapi_client.sh
└── sync_github_data.py
```

## Notes on Structure
- Keep feature code close to its UI and business logic.
- Use repositories for persistence only; keep HTTP and GitHub SDK calls in services.
- Keep route guards and app-level configuration isolated in `core/` and `routes/`.
- Use the backend API version prefix `/api/v1` from day one.
- Keep generated files and build artifacts out of source control.

