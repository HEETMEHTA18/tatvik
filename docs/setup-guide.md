# Setup Guide

## Prerequisites
- Flutter SDK
- Python 3.11+
- PostgreSQL 15+
- Redis
- GitHub OAuth app credentials
- Google OAuth credentials
- OpenAI API key or Ollama instance

## Repository Setup
```bash
git clone https://github.com/your-org/tatvik.git
cd tatvik
```

## Frontend Setup

### 1. Install dependencies
```bash
flutter pub get
```

### 2. Configure environment
Create a frontend config file or use your preferred env injection strategy.

Example values:
```env
API_BASE_URL=http://localhost:8000/api/v1
APP_ENV=development
```

### 3. Run the app
```bash
flutter run
```

### 4. Optional quality checks
```bash
flutter analyze
flutter test
```

## Backend Setup

### 1. Create the backend project
```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -U pip
```

### 2. Install dependencies
```bash
pip install -r requirements.txt
```

### 3. Configure environment variables
Create `backend/.env`:
```env
ENVIRONMENT=development
API_V1_PREFIX=/api/v1
DATABASE_URL=postgresql+psycopg://postgres:postgres@localhost:5432/tatvik
REDIS_URL=redis://localhost:6379/0
JWT_SECRET_KEY=change-me
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=60
JWT_REFRESH_TOKEN_EXPIRE_DAYS=30
GITHUB_CLIENT_ID=your_github_client_id
GITHUB_CLIENT_SECRET=your_github_client_secret
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
OPENAI_API_KEY=your_openai_key
OLLAMA_BASE_URL=http://localhost:11434
SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_ROLE_KEY=your_supabase_key
```

### 4. Run database migrations
```bash
alembic upgrade head
```

### 5. Start the API server
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 6. Run backend tests
```bash
pytest
```

## Local Services

### PostgreSQL
Create a database named `tatvik`.

Example:
```bash
createdb tatvik
```

### Redis
```bash
redis-server
```

## OAuth Setup

### GitHub OAuth
1. Open GitHub Developer Settings.
2. Create a new OAuth App.
3. Set the homepage URL to the frontend URL.
4. Set the callback URL to the backend OAuth callback endpoint.

### Google OAuth
1. Create OAuth credentials in Google Cloud Console.
2. Add your frontend and backend redirect URIs.
3. Store client ID and secret in `backend/.env`.

## Deployment Setup

### Backend on Railway
- Connect the repository.
- Set backend environment variables.
- Configure PostgreSQL and Redis integrations.
- Deploy from the `backend/` directory.

### Database on Neon
- Create a managed PostgreSQL database.
- Copy the connection string into `DATABASE_URL`.
- Run migrations after the first deploy.

### Frontend on Firebase Hosting
- Build the Flutter web target.
- Deploy the generated build artifacts to Firebase Hosting.

### Storage on Supabase
- Create a storage bucket for avatars and generated assets.
- Use service role keys only on the backend.

## Verification Checklist
- Backend starts without errors.
- Flutter app can reach the API.
- OAuth redirects are configured correctly.
- Database migrations run successfully.
- Redis is available for caching and throttling.
