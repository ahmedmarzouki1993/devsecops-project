"""
Pydantic models used as request/response schemas.
SQLAlchemy ORM models would live here too in a full implementation.
Using in-memory store for this demo to keep the focus on DevSecOps, not ORM setup.
"""
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field


# ── Items ──────────────────────────────────────────────────────────────────────

class ItemBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    price: float = Field(..., gt=0)


class ItemCreate(ItemBase):
    pass


class ItemUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    price: Optional[float] = Field(None, gt=0)


class Item(ItemBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime


# ── Users ──────────────────────────────────────────────────────────────────────

class UserBase(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    email: str = Field(..., pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class UserCreate(UserBase):
    pass


class UserUpdate(BaseModel):
    username: Optional[str] = Field(None, min_length=3, max_length=50)
    email: Optional[str] = Field(None, pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class User(UserBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
