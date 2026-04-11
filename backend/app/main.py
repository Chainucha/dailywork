from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from app.config import settings
from app.routers import auth, users, workers, employers, jobs, applications, reviews, notifications, categories

limiter = Limiter(key_func=get_remote_address)


def create_app() -> FastAPI:
    app = FastAPI(
        title="Worker Job Board API",
        version="1.0.0",
        docs_url="/docs" if settings.APP_ENV == "development" else None,
        redoc_url=None,
    )

    # Rate limiter
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

    # Middleware
    app.add_middleware(GZipMiddleware, minimum_size=1000)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.ALLOWED_ORIGINS,
        allow_methods=["*"],
        allow_headers=["Authorization", "Content-Type"],
    )

    # Global error handler
    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception):
        return JSONResponse(
            status_code=500,
            content={"detail": "Internal server error"},
        )

    # Routers
    PREFIX = "/api/v1"
    app.include_router(auth.router,          prefix=f"{PREFIX}/auth")
    app.include_router(users.router,         prefix=f"{PREFIX}/users")
    app.include_router(workers.router,       prefix=f"{PREFIX}/workers")
    app.include_router(employers.router,     prefix=f"{PREFIX}/employers")
    app.include_router(jobs.router,          prefix=f"{PREFIX}/jobs")
    # applications router has routes under /jobs/{id}/apply|applications AND /applications/{id}
    # Register at /api/v1 so both path shapes resolve correctly, using a sub-router for PATCH
    app.include_router(applications.router,  prefix=f"{PREFIX}")
    app.include_router(reviews.router,       prefix=f"{PREFIX}/reviews")
    app.include_router(notifications.router, prefix=f"{PREFIX}/notifications")
    app.include_router(categories.router,    prefix=f"{PREFIX}/categories")

    @app.get("/health")
    async def health():
        db_status = "ok"
        try:
            from app.supabase_client import get_supabase
            db = get_supabase()
            db.table("categories").select("id").limit(1).execute()
        except Exception as e:
            db_status = f"error: {e}"
        return {"status": "ok", "database": db_status}

    return app


app = create_app()
