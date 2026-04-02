"""
Metrics endpoints:
  /metrics           — Prometheus text format (scraped by Prometheus)
  /api/v1/metrics/   — JSON summary (for humans/dashboards)

prometheus_fastapi_instrumentator automatically tracks:
  - HTTP request count by method/path/status
  - HTTP request latency histogram
  - In-flight requests gauge
"""
from fastapi import APIRouter, Depends, Response
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest
from sqlalchemy.orm import Session

from app import crud
from app.database import get_db

router = APIRouter(prefix="/metrics", tags=["metrics"])


@router.get("/", summary="Application metrics (JSON)")
def app_metrics(db: Session = Depends(get_db)) -> dict:
    return {
        "items_count": crud.count_items(db),
        "users_count": crud.count_users(db),
    }


# Standalone /metrics route (no /api/v1 prefix) for Prometheus scraping
prometheus_router = APIRouter(tags=["metrics"])


@prometheus_router.get("/metrics", include_in_schema=False)
def prometheus_metrics() -> Response:
    """Prometheus scrape endpoint — returns metrics in text exposition format."""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
