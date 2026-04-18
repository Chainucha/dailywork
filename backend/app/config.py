from pydantic import model_validator
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Supabase
    SUPABASE_URL: str
    SUPABASE_ANON_KEY: str                 # anon/public key — used for Auth API calls
    SUPABASE_SERVICE_ROLE_KEY: str    # service role key — used for DB (bypasses RLS)

    # JWT — JWKS (RS256) is primary; HS256 secret is optional fallback
    SUPABASE_JWKS_URL: str = ""
    SUPABASE_JWT_SECRET: str = ""

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # Celery
    CELERY_BROKER_URL: str = "redis://localhost:6379/1"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/1"

    # App
    APP_ENV: str = "development"
    ALLOWED_ORIGINS: list[str] = ["*"]
    RATE_LIMIT_DEFAULT: str = "60/minute"

    # Firebase Cloud Messaging
    FCM_SERVER_KEY: str = ""

    @model_validator(mode="after")
    def _default_jwks_url(self) -> "Settings":
        if not self.SUPABASE_JWKS_URL:
            self.SUPABASE_JWKS_URL = (
                f"{self.SUPABASE_URL}/auth/v1/.well-known/jwks.json"
            )
        return self

    class Config:
        env_file = ".env"


settings = Settings()
