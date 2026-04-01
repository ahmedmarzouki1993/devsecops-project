"""
SQLAlchemy 2.0 ORM models — the actual database tables.

WHY SEPARATE FROM models.py?
  models.py = Pydantic schemas  → what the API accepts/returns (HTTP layer)
  db_models.py = SQLAlchemy ORM → what the database stores (persistence layer)
  Keeping them separate means you can change your DB schema without breaking
  the API contract, and vice versa. This is the Repository Pattern.

MODERN SQLALCHEMY 2.0 STYLE:
  - DeclarativeBase (not the old declarative_base() function)
  - Mapped[type] + mapped_column() instead of Column()
  - Python type hints drive column nullability automatically
"""
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import String, Text, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


def _utcnow() -> datetime:
    """UTC timestamp helper — used as server_default for created_at columns."""
    return datetime.now(timezone.utc)


class Base(DeclarativeBase):
    """
    Shared base for all ORM models.
    All tables registered here are created by Alembic migrations.
    """
    pass


class ItemORM(Base):
    """
    Database table: items
    Mapped to the Pydantic Item schema in models.py via crud.py.
    """
    __tablename__ = "items"

    # Primary key — auto-incremented integer, never nullable
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)

    # String columns — String(100) sets VARCHAR(100) in the DDL
    name: Mapped[str] = mapped_column(String(100), nullable=False, index=True)

    # Optional[str] → SQLAlchemy infers nullable=True automatically
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Price — stored as float. In production use Numeric(10,2) for money.
    price: Mapped[float] = mapped_column(nullable=False)

    # server_default: the DB sets this on INSERT if not provided.
    # func.now() = database-side NOW() — consistent even if app clock drifts.
    created_at: Mapped[datetime] = mapped_column(
        nullable=False,
        server_default=func.now(),
    )

    def __repr__(self) -> str:
        return f"<Item id={self.id} name={self.name!r} price={self.price}>"


class UserORM(Base):
    """
    Database table: users
    Mapped to the Pydantic User schema in models.py via crud.py.
    """
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)

    # unique=True → DB-level unique constraint (not just app-level validation)
    username: Mapped[str] = mapped_column(String(50), nullable=False, unique=True, index=True)
    email: Mapped[str] = mapped_column(String(254), nullable=False, unique=True)

    created_at: Mapped[datetime] = mapped_column(
        nullable=False,
        server_default=func.now(),
    )

    def __repr__(self) -> str:
        return f"<User id={self.id} username={self.username!r}>"
