"""
Health probe endpoints — no /api prefix so kubelet reaches them directly.

/healthz → liveness  (is the process alive? if fails → K8s restarts the pod)
/readyz  → readiness (is the app ready? if fails → K8s removes pod from Service endpoints)

WHY check DB in readyz?
  A pod might be running but can't reach the database yet (DB still starting).
  Returning 503 on /readyz tells K8s to stop sending traffic until DB is up.
  Without this, users get 500 errors during startup or DB reconnect.
"""
from fastapi import APIRouter
from app.database import check_db_connection

router = APIRouter(tags=["health"])


@router.get("/healthz", summary="Liveness probe")
def liveness() -> dict:
    """Returns 200 as long as the process is running."""
    return {"status": "alive"}


@router.get("/readyz", summary="Readiness probe")
def readiness() -> dict:
    """
    Returns 200 when the app AND database are ready to serve traffic.
    Returns 503 if the DB is unreachable (K8s will stop routing to this pod).
    """
    from fastapi import HTTPException
    if not check_db_connection():
        raise HTTPException(status_code=503, detail="database unavailable")
    return {"status": "ready"}
