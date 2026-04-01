"""
Test configuration — injects SQLite in-memory database before the app starts.

WHY SET ENV VAR FIRST?
  database.py creates the engine at module import time using settings.database_url.
  Setting DATABASE_URL in os.environ BEFORE importing app modules makes
  pydantic-settings read SQLite instead of PostgreSQL.
  Then patching db_module.engine ensures the lifespan's create_tables() also
  uses SQLite — so startup doesn't try to connect to a real PostgreSQL server.
"""
import os

# Must be set BEFORE any app imports — pydantic-settings reads env at import time
os.environ["DATABASE_URL"] = "sqlite:///:memory:"

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

# Import and patch the database module before importing the app
import app.database as db_module
from app.db_models import Base

# Single shared SQLite engine with StaticPool so all connections see the same data
_test_engine = create_engine(
    "sqlite:///:memory:",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
_TestSession = sessionmaker(bind=_test_engine, autocommit=False, autoflush=False)

# Patch database module — now create_tables() and get_db() both use SQLite
db_module.engine = _test_engine
db_module.SessionLocal = _TestSession

# Import app AFTER patching so lifespan uses our test engine
from app.main import app  # noqa: E402
from app.database import get_db  # noqa: E402


@pytest.fixture(autouse=True)
def setup_db():
    """Fresh tables before each test, dropped after. autouse=True = runs for every test."""
    Base.metadata.create_all(bind=_test_engine)
    yield
    Base.metadata.drop_all(bind=_test_engine)


@pytest.fixture
def client():
    """TestClient with get_db() overridden to use the SQLite test session."""
    def override_get_db():
        session = _TestSession()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()
