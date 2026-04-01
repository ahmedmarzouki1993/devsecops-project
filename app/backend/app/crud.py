"""
CRUD operations — the data access layer between routers and the database.

WHY A SEPARATE crud.py?
  Routers handle HTTP (request parsing, response formatting, status codes).
  CRUD handles database logic (queries, transactions, ORM operations).
  Separating them means:
  - You can test CRUD functions without HTTP (just pass a Session)
  - You can swap the DB layer without touching router code
  - Multiple routes can reuse the same CRUD function

PATTERN:
  Every function takes a db: Session as its first argument.
  The session comes from the get_db() dependency in the router.
  Functions return ORM objects — the router's response_model converts them to JSON.
"""
from typing import Optional

from sqlalchemy.orm import Session

from app.db_models import ItemORM, UserORM


# ── Items ──────────────────────────────────────────────────────────────────────

def get_items(db: Session) -> list[ItemORM]:
    """Return all items ordered by id."""
    return db.query(ItemORM).order_by(ItemORM.id).all()


def get_item(db: Session, item_id: int) -> Optional[ItemORM]:
    """Return a single item by primary key, or None if not found."""
    return db.get(ItemORM, item_id)


def create_item(db: Session, name: str, price: float, description: Optional[str] = None) -> ItemORM:
    """
    Insert a new item row.
    db.add() stages the object. db.commit() writes to DB. db.refresh() reloads
    the row (needed to get server-set values like created_at and auto-increment id).
    """
    item = ItemORM(name=name, price=price, description=description)
    db.add(item)
    db.commit()
    db.refresh(item)  # reload from DB to get server_default values
    return item


def update_item(
    db: Session,
    item_id: int,
    name: Optional[str] = None,
    price: Optional[float] = None,
    description: Optional[str] = None,
) -> Optional[ItemORM]:
    """
    Partial update — only changes fields that are not None.
    Returns the updated item, or None if not found.
    """
    item = db.get(ItemORM, item_id)
    if not item:
        return None
    # Only update fields explicitly provided (partial PATCH semantics)
    if name is not None:
        item.name = name
    if price is not None:
        item.price = price
    if description is not None:
        item.description = description
    db.commit()
    db.refresh(item)
    return item


def delete_item(db: Session, item_id: int) -> bool:
    """Delete item by id. Returns True if deleted, False if not found."""
    item = db.get(ItemORM, item_id)
    if not item:
        return False
    db.delete(item)
    db.commit()
    return True


def count_items(db: Session) -> int:
    """Return total number of items — used by the metrics endpoint."""
    return db.query(ItemORM).count()


# ── Users ──────────────────────────────────────────────────────────────────────

def get_users(db: Session) -> list[UserORM]:
    """Return all users ordered by id."""
    return db.query(UserORM).order_by(UserORM.id).all()


def get_user(db: Session, user_id: int) -> Optional[UserORM]:
    """Return a single user by primary key, or None if not found."""
    return db.get(UserORM, user_id)


def create_user(db: Session, username: str, email: str) -> UserORM:
    """Insert a new user row."""
    user = UserORM(username=username, email=email)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def update_user(
    db: Session,
    user_id: int,
    username: Optional[str] = None,
    email: Optional[str] = None,
) -> Optional[UserORM]:
    """Partial update for user fields."""
    user = db.get(UserORM, user_id)
    if not user:
        return None
    if username is not None:
        user.username = username
    if email is not None:
        user.email = email
    db.commit()
    db.refresh(user)
    return user


def delete_user(db: Session, user_id: int) -> bool:
    """Delete user by id. Returns True if deleted, False if not found."""
    user = db.get(UserORM, user_id)
    if not user:
        return False
    db.delete(user)
    db.commit()
    return True


def count_users(db: Session) -> int:
    """Return total number of users — used by the metrics endpoint."""
    return db.query(UserORM).count()
