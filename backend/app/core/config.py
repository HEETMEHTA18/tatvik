from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    environment: str = "development"
    api_v1_prefix: str = "/api/v1"
    project_name: str = "DevMentor API"
    database_url: str = "sqlite:///./devmentor.db"
    jwt_secret_key: str = "change-me"
    jwt_algorithm: str = "HS256"
    jwt_access_expire_minutes: int = 10080  # 7 days (60 * 24 * 7)
    redis_url: str = "redis://localhost:6379/0"
    gemini_api_key: str = ""
    groq_api_key: str = ""
    GOOGLE_CLIENT_ID: str = "google-client-id"
    GOOGLE_CLIENT_SECRET: str = "google-client-secret"


settings = Settings()
