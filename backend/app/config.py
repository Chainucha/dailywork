from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Supabase
    SUPABASE_URL: str
    SUPABASE_SERVICE_ROLE_KEY: str
    SUPABASE_JWT_SECRET: str

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

    class Config:
        env_file = ".env"


settings = Settings()
