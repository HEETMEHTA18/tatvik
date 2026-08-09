from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    environment: str = "development"
    api_v1_prefix: str = "/api/v1"
    project_name: str = "Tatvik API"
    database_url: str = "sqlite:///./tatvik.db"
    jwt_secret_key: str = "change-me"
    jwt_algorithm: str = "HS256"
    jwt_access_expire_minutes: int = 10080  # 7 days (60 * 24 * 7)
    redis_url: str = "redis://localhost:6379/0"

    # ── LLM / Intelligence Layer ──────────────────────────────────────────────
    gemini_api_key: str = ""
    # Preferred Gemini model and fallback to use when quota/exhausted
    gemini_model: str = "gemini-2.5-flash"
    gemini_fallback_model: str = "gemini-2.5-flash-lite"
    gemini_max_retries: int = 3
    gemini_backoff_base: float = 1.0
    groq_api_key: str = ""
    openrouter_api_key: str = ""
    nvidia_api_key: str = ""

    # ── Google OAuth ──────────────────────────────────────────────────────────
    GOOGLE_CLIENT_ID: str = "google-client-id"
    GOOGLE_CLIENT_SECRET: str = "google-client-secret"

    # ── Cognee Memory Layer ───────────────────────────────────────────────────
    cognee_api_key: str = ""
    cognee_base_url: str = (
        "https://tenant-8a941fb2-e171-4bac-8bdc-48b1f70cf20c.aws.cognee.ai"
    )
    cognee_brain_name: str = "Tatvik brain"

    # ── OpenClaw Execution Engine ─────────────────────────────────────────────
    openclaw_api_key: str = ""
    openclaw_api_url: str = "https://api.openclaw.ai/v1"

    # ── GitHub Integration ────────────────────────────────────────────────────
    github_token: str = ""
    github_webhook_secret: str = ""
    # GitHub OAuth App credentials (used for "Continue with GitHub" login).
    # MUST come from Render env vars — never hardcode secrets in the repo.
    # Accept several common env var names for flexibility.
    github_oauth_client_id: str = Field(
        default="",
        validation_alias=AliasChoices(
            "GITHUB_OAUTH_CLIENT_ID", "GITHUB_CLIENT_ID", "GITHUB_OAUTH_ID"
        ),
    )
    github_oauth_client_secret: str = Field(
        default="",
        validation_alias=AliasChoices(
            "GITHUB_OAUTH_CLIENT_SECRET",
            "GITHUB_CLIENT_SECRET",
            "GITHUB_OAUTH_SECRET",
        ),
    )

    # Frontend origin for OAuth success/error redirects.
    # Override with FRONTEND_BASE_URL when needed.
    frontend_base_url: str = Field(
        default="https://tatvik.vercel.app",
        validation_alias=AliasChoices(
            "FRONTEND_BASE_URL", "FRONTEND_URL", "VITE_FRONTEND_URL"
        ),
    )

    # ── Notion Integration ────────────────────────────────────────────────────
    notion_api_key: str = ""
    notion_root_database_id: str = ""

    # ── Slack Integration ─────────────────────────────────────────────────────
    slack_bot_token: str = ""
    slack_signing_secret: str = ""
    slack_default_channel: str = "#general"

    # ── Discord Integration ───────────────────────────────────────────────────
    discord_bot_token: str = ""
    discord_default_channel_id: str = ""

    # ── Email via SMTP (iCloud, Gmail app-password, Outlook — simpler than OAuth) ──
    smtp_host: str = "smtp.mail.me.com"  # iCloud default; use smtp.gmail.com for Gmail
    smtp_port: int = 587
    smtp_username: str = ""
    smtp_password: str = ""  # App-specific password (NOT your account password)
    smtp_from_email: str = ""

    # ── Apple Calendar via CalDAV (alternative to Google Calendar OAuth) ─────────
    apple_caldav_url: str = "https://caldav.icloud.com"
    apple_caldav_username: str = ""  # Your Apple ID email
    apple_caldav_password: str = ""  # App-specific password from appleid.apple.com

    # ── Gmail / Google Calendar (OAuth — optional, SMTP is recommended instead) ──
    gmail_credentials_json: str = ""

    # ── Jira Integration ──────────────────────────────────────────────────────
    jira_base_url: str = ""
    jira_api_token: str = ""
    jira_email: str = ""
    jira_default_project: str = ""

    # ── Linear Integration ────────────────────────────────────────────────────
    linear_api_key: str = ""
    linear_default_team: str = ""

    # ── Vercel Integration ────────────────────────────────────────────────────
    vercel_token: str = ""
    vercel_team_id: str = ""

    # ── Railway Integration ───────────────────────────────────────────────────
    railway_api_token: str = ""

    # ── AWS Integration ───────────────────────────────────────────────────────
    aws_access_key_id: str = ""
    aws_secret_access_key: str = ""
    aws_region: str = "us-east-1"

    # ── Firebase Integration ──────────────────────────────────────────────────
    firebase_credentials_json: str = ""
    firebase_project_id: str = ""

    # ── Supabase Integration ──────────────────────────────────────────────────
    supabase_url: str = ""
    supabase_service_key: str = ""

    # ── Figma Integration ─────────────────────────────────────────────────────
    figma_access_token: str = ""

    # ── Docker Integration ────────────────────────────────────────────────────
    docker_host: str = "unix:///var/run/docker.sock"

    # ── Background Pulse Scanner — memory-constrained settings ────────────────
    enable_pulse_scanner: bool = True
    pulse_scanner_interval_seconds: int = (
        43200  # 12 hours — prevents OOM on free-tier hosting
    )
    pulse_max_items_per_feed: int = (
        2  # Only 2 most recent items to reduce API/memory overhead
    )


settings = Settings()
