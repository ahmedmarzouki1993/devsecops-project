"""
Metrics endpoint — mounted at /api/v1/metrics.
Returns live counts from the database (not in-memory).
In Phase 7, prometheus_fastapi_instrumentator replaces this with a proper
/metrics endpoint in Prometheus text format.
"""
from fastapi import APIRouter, Depends
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
