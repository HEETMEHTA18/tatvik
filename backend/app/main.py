import logging
import time

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.api.router import api_router
from app.core.exceptions import ApiException
from app.core.logging import configure_logging
from app.db.base import Base
from app.db.session import engine, SessionLocal
import asyncio
from app.services.news_scanner import scan_tech_news

configure_logging()
logger = logging.getLogger(__name__)

from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="DevMentor API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"https://(devsmentor\.vercel\.app|devmentor\.vercel\.app)|http://(localhost|127\.0\.0\.1)(:[0-9]+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


async def periodic_news_scanner():
    await asyncio.sleep(5)
    while True:
        try:
            logger.info("Periodic news scanner running...")
            db = SessionLocal()
            try:
                await scan_tech_news(db)
            finally:
                db.close()
        except Exception as e:
            logger.error(f"Error in periodic news scanner: {e}")
        # Run scan every hour (3600 seconds)
        await asyncio.sleep(3600)


@app.on_event("startup")
def startup_event():
    Base.metadata.create_all(bind=engine)

    # Custom self-healing migrations for users columns using schema inspection (PostgreSQL safe)
    from sqlalchemy import text, inspect

    try:
        inspector = inspect(engine)
        columns = [col["name"] for col in inspector.get_columns("users")]

        if "personal_goal" not in columns:
            logger.info("Adding column personal_goal to users table")
            with engine.begin() as conn:
                conn.execute(
                    text("ALTER TABLE users ADD COLUMN personal_goal VARCHAR(512)")
                )

        if "preferred_stack" not in columns:
            logger.info("Adding column preferred_stack to users table")
            with engine.begin() as conn:
                conn.execute(
                    text("ALTER TABLE users ADD COLUMN preferred_stack VARCHAR(512)")
                )
    except Exception as e:
        logger.error(f"Error executing startup database migration: {e}")

    asyncio.create_task(periodic_news_scanner())


@app.middleware("http")
async def request_timing_middleware(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    duration_ms = round((time.perf_counter() - start) * 1000, 2)
    response.headers["X-Process-Time-Ms"] = str(duration_ms)

    # Inject security headers
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["X-XSS-Protection"] = "1; mode=block"

    logger.info(
        "%s %s -> %s (%sms)",
        request.method,
        request.url.path,
        response.status_code,
        duration_ms,
    )
    return response


@app.exception_handler(ApiException)
async def api_exception_handler(_: Request, exc: ApiException):
    return JSONResponse(
        status_code=exc.status_code, content={"success": False, "error": exc.detail}
    )


@app.exception_handler(ValueError)
async def value_error_handler(_: Request, exc: ValueError):
    return JSONResponse(
        status_code=401,
        content={
            "success": False,
            "error": {"code": "AUTH_INVALID_TOKEN", "message": str(exc)},
        },
    )


@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    response = JSONResponse(
        status_code=500,
        content={
            "success": False,
            "error": {
                "code": "INTERNAL_SERVER_ERROR",
                "message": str(exc),
                "type": type(exc).__name__,
            },
        },
    )
    origin = request.headers.get("origin")
    if origin:
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Access-Control-Allow-Credentials"] = "true"
        response.headers["Access-Control-Allow-Methods"] = "*"
        response.headers["Access-Control-Allow-Headers"] = "*"
    return response


@app.get("/health")
def health_check():
    return {"status": "ok"}


app.include_router(api_router)
