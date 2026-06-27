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
    gemini_api_key: str = ""
    groq_api_key: str = ""
    openrouter_api_key: str = ""
    nvidia_api_key: str = ""
    GOOGLE_CLIENT_ID: str = "google-client-id"
    GOOGLE_CLIENT_SECRET: str = "google-client-secret"
    cognee_api_key: str = ""
    cognee_base_url: str = (
        "https://tenant-8a941fb2-e171-4bac-8bdc-48b1f70cf20c.aws.cognee.ai"
    )
    openclaw_api_key: str = ""
    openclaw_api_url: str = "https://api.openclaw.ai/v1"

    # Background Pulse Scanner Configuration to avoid OOM memory limits
    enable_pulse_scanner: bool = True
    pulse_scanner_interval_seconds: int = (
        43200  # Default to 12 hours instead of 1 hour to prevent high memory usage
    )
    pulse_max_items_per_feed: int = (
        2  # Only process the 2 most recent items to avoid API/memory overhead
    )


settings = Settings()
