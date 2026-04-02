"""
FastAPI application entrypoint.

LIFESPAN:
  FastAPI's lifespan context manager runs startup/shutdown logic.
  On startup: create DB tables (idempotent — safe to run every time).
  On shutdown: nothing needed (SQLAlchemy closes pool automatically).

  In production (Phase 3+), Alembic migrations handle schema changes.
  create_tables() is a safety net for first startup in a fresh environment.
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from prometheus_fastapi_instrumentator import Instrumentator

from app.database import create_tables
from app.routers import health, items, metrics, users


@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── Startup ──────────────────────────────────────────────────────────────
    # Create tables if they don't exist (safe to call multiple times).
    # Alembic migrations take over in Phase 3 for schema changes.
    create_tables()
    yield
    # ── Shutdown ─────────────────────────────────────────────────────────────
    # SQLAlchemy disposes the connection pool automatically on process exit.


app = FastAPI(
    title="DevSecOps Demo API",
    description="3-tier demo app — FastAPI backend",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json",
    lifespan=lifespan,
)

# CORS — allow the React frontend origin.
# In production, restrict allow_origins to the actual frontend URL.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health probes — no /api prefix so kubelet reaches them directly
app.include_router(health.router)

# Versioned API routes — all under /api/v1/
app.include_router(items.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(metrics.router, prefix="/api/v1")

# /metrics — Prometheus scrape endpoint (no /api prefix, Prometheus expects root path)
app.include_router(metrics.prometheus_router)

# Instrument all routes: tracks request count, latency, in-flight requests
Instrumentator().instrument(app).expose(app, endpoint="/metrics", include_in_schema=False)
