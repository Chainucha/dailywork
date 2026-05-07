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

    # App
    APP_ENV: str = "development"
    ALLOWED_ORIGINS: list[str] = ["*"]
    RATE_LIMIT_DEFAULT: str = "60/minute"

    # Dev-only bypass — ignored when APP_ENV=production
    DEV_WORKER_PHONE: str = ""    # e.g. +10000000001
    DEV_EMPLOYER_PHONE: str = ""  # e.g. +10000000002
    DEV_BYPASS_OTP: str = "000000"

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
