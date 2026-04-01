"""
Database engine, session factory, and FastAPI dependency.

HOW THIS WORKS WITH FASTAPI:
  Every HTTP request gets its own database session via get_db().
  FastAPI's Depends() calls get_db(), yields the session to the route handler,
  then the finally block closes it — even if the handler raises an exception.

  Request → get_db() → Session created → route handler runs → Session closed

WHY yield (not return)?
  yield turns get_db() into a context manager.
  Code after yield runs during response teardown (cleanup phase).
  This guarantees the session is always closed, preventing connection leaks.

CONNECTION POOLING:
  SQLAlchemy maintains a pool of connections (default: 5 + 10 overflow).
  Sessions borrow a connection from the pool and return it on close().
  For a single-node dev cluster, the default pool size is fine.
"""
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, Session

from app.config import settings
from app.db_models import Base

# ── Engine ─────────────────────────────────────────────────────────────────────
# The engine is the connection to the database.
# create_engine() is called ONCE at startup — it creates the connection pool.
#
# echo=False in production (True would log every SQL query — useful for debugging)
# pool_pre_ping=True: before handing a connection from the pool, check it's alive.
#   Without this, a long-idle connection might be dead (DB restarted, firewall timeout)
#   and the first query on it would fail. pool_pre_ping sends "SELECT 1" to verify.
engine = create_engine(
    settings.database_url,
    echo=settings.app_env == "development",  # log SQL in dev, silent in prod
    pool_pre_ping=True,
)

# ── Session factory ────────────────────────────────────────────────────────────
# SessionLocal is a class (factory). Calling SessionLocal() creates a new session.
# autocommit=False → you must explicitly call db.commit() to persist changes
# autoflush=False  → SQLAlchemy won't auto-flush pending changes before queries
#                    (prevents unexpected INSERTs mid-transaction)
SessionLocal = sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
)


def create_tables() -> None:
    """
    Create all tables defined in db_models.py if they don't exist.
    Called once at app startup (see main.py lifespan).
    In production, Alembic migrations handle schema changes instead.
    """
    Base.metadata.create_all(bind=engine)


def get_db():
    """
    FastAPI dependency — yields a database session per request.

    Usage in a route:
        from app.database import get_db
        from sqlalchemy.orm import Session

        @router.get("/items")
        def list_items(db: Session = Depends(get_db)):
            ...
    """
    db: Session = SessionLocal()
    try:
        yield db          # hand session to the route handler
    finally:
        db.close()        # always close — returns connection to pool


def check_db_connection() -> bool:
    """
    Health check helper — verifies DB is reachable.
    Used by the /readyz endpoint so K8s knows when the app is truly ready.
    """
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False
