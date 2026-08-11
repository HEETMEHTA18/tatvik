# API Specification

## Versioning
- **Base URL:** `https://api.tatvik.app/api/v1`
- All endpoints should be versioned.
- Breaking changes must ship under a new version.

## Standards

### Authentication Headers
```http
Authorization: Bearer <access_token>
Content-Type: application/json
Accept: application/json
```

### Common Response Envelope
```json
{
  "success": true,
  "data": {},
  "message": "OK",
  "meta": {}
}
```

### Common Error Response
```json
{
  "success": false,
  "error": {
    "code": "AUTH_INVALID_TOKEN",
    "message": "Access token is missing or invalid.",
    "details": {}
  }
}
```

### Pagination
```json
{
  "items": [],
  "page": 1,
  "page_size": 20,
  "total_items": 120,
  "total_pages": 6
}
```

### Rate Limiting
- Apply per-IP and per-user limits for auth, mentor chat, and expensive analysis endpoints.
- Return `429 Too Many Requests` with a retry hint.

## Authentication Endpoints

### `POST /auth/register`
Create an email-based account.

**Request**
```json
{
  "email": "dev@example.com",
  "password": "StrongPassword123!",
  "name": "Alex Doe"
}
```

### `POST /auth/login`
Authenticate with email and password.

### `POST /auth/github`
Exchange GitHub OAuth code for JWT tokens.

### `POST /auth/google`
Exchange Google OAuth token/code for JWT tokens.

### `POST /auth/refresh`
Issue a new access token using a valid refresh token.

### `POST /auth/logout`
Invalidate the current session.

### `GET /auth/me`
Return the currently authenticated user.

## Users Endpoints

### `GET /users/me`
Return profile, preferences, and connected provider summary.

### `PATCH /users/me`
Update user profile fields such as name, bio, target role, and preferences.

### `GET /users/me/activity`
Return recent platform activity and analysis events.

### `GET /users/me/sessions`
List active sessions for device management.

## GitHub Endpoints

### `POST /github/connect`
Connect a GitHub account.

### `POST /github/sync`
Trigger a manual GitHub sync.

### `GET /github/profile`
Return normalized GitHub profile data.

### `GET /github/repositories`
Return the user’s synced repositories.

### `GET /github/activity`
Return contribution summary and heatmap data.

### `GET /github/languages`
Return language usage and stack distribution.

## Repositories Endpoints

### `GET /repositories`
List repositories owned, analyzed, or saved by the user.

### `GET /repositories/{repository_id}`
Return a repository detail document.

### `POST /repositories/{repository_id}/analyze`
Trigger a repository analysis job.

### `GET /repositories/{repository_id}/insights`
Return AI-generated repository insights.

### `POST /repositories/{repository_id}/bookmark`
Save a repository for later review.

### `DELETE /repositories/{repository_id}/bookmark`
Remove a saved repository.

## Analysis Endpoints

### `POST /analysis/run`
Run a full developer analysis cycle.

### `GET /analysis/latest`
Return the latest generated analysis for the user.

### `GET /analysis/history`
Return all historical analysis snapshots.

### `GET /analysis/skill-matrix`
Return normalized skill scores and categories.

### `GET /analysis/skill-gaps`
Return detected gaps and recommendations.

### `GET /analysis/developer-score`
Return the current score and contributing factors.

## Roadmap Endpoints

### `POST /roadmap/generate`
Generate or regenerate a personalized roadmap.

### `GET /roadmap/current`
Return the active roadmap.

### `PATCH /roadmap/milestones/{milestone_id}`
Mark a milestone as completed or update its status.

### `POST /roadmap/milestones/{milestone_id}/notes`
Add notes or reflections to a milestone.

### `GET /roadmap/progress`
Return completion metrics and timeline summaries.

## Mentor Endpoints

### `POST /mentor/chats`
Create a new mentor chat thread.

### `GET /mentor/chats`
List mentor chat threads.

### `GET /mentor/chats/{chat_id}`
Fetch a chat thread and message history.

### `POST /mentor/chats/{chat_id}/messages`
Send a user message and receive an AI response.

### `DELETE /mentor/chats/{chat_id}`
Archive or delete a chat thread.

## Recommendations Endpoints

### `GET /recommendations/repositories`
Return recommended repositories to study.

### `GET /recommendations/projects`
Return recommended portfolio and startup projects.

### `GET /recommendations/open-source`
Return open-source contribution opportunities.

### `POST /recommendations/{recommendation_id}/feedback`
Capture feedback such as saved, dismissed, or not relevant.

## Request/Response Schemas

### Auth Token Response
```json
{
  "access_token": "jwt.access.token",
  "refresh_token": "jwt.refresh.token",
  "token_type": "bearer",
  "expires_in": 3600,
  "user": {
    "id": "uuid",
    "name": "Alex Doe",
    "email": "dev@example.com"
  }
}
```

### Developer Score Response
```json
{
  "score": 82,
  "grade": "B+",
  "factors": [
    { "name": "consistency", "weight": 0.3, "value": 78 },
    { "name": "open_source", "weight": 0.2, "value": 65 }
  ],
  "trend": "up",
  "delta": 4
}
```

### Mentor Message Request
```json
{
  "message": "What should I learn next?",
  "context": {
    "target_role": "Frontend Engineer",
    "current_focus": ["Flutter", "Dart"]
  }
}
```

### Mentor Message Response
```json
{
  "assistant_message": "Focus on state management, testing, and architecture next.",
  "citations": ["analysis.latest", "roadmap.current"],
  "suggested_actions": [
    "Review the Riverpod docs",
    "Build a medium-complexity portfolio app"
  ]
}
```

## Error Codes
- `AUTH_INVALID_TOKEN`
- `AUTH_EXPIRED_TOKEN`
- `AUTH_PROVIDER_FAILED`
- `GITHUB_RATE_LIMITED`
- `ANALYSIS_FAILED`
- `ROADMAP_NOT_FOUND`
- `MENTOR_PROVIDER_ERROR`
- `VALIDATION_ERROR`
- `RESOURCE_NOT_FOUND`
- `INTERNAL_SERVER_ERROR`

## OpenAPI Requirements
- Generate OpenAPI documentation automatically.
- Include tags for each major module.
- Provide example requests and responses.
- Document auth requirements for protected routes.

