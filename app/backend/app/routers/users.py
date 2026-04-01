"""
Users CRUD router — mounted at /api/v1/users.
Uses SQLAlchemy session via FastAPI's Depends(get_db) dependency injection.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app import crud
from app.database import get_db
from app.models import User, UserCreate, UserUpdate

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/", response_model=list[User], summary="List all users")
def list_users(db: Session = Depends(get_db)) -> list:
    return crud.get_users(db)


@router.post("/", response_model=User, status_code=status.HTTP_201_CREATED, summary="Create user")
def create_user(payload: UserCreate, db: Session = Depends(get_db)) -> object:
    return crud.create_user(db, **payload.model_dump())


@router.get("/{user_id}", response_model=User, summary="Get user by ID")
def get_user(user_id: int, db: Session = Depends(get_db)) -> object:
    user = crud.get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail=f"User {user_id} not found")
    return user


@router.put("/{user_id}", response_model=User, summary="Update user")
def update_user(user_id: int, payload: UserUpdate, db: Session = Depends(get_db)) -> object:
    user = crud.update_user(db, user_id, **payload.model_dump())
    if not user:
        raise HTTPException(status_code=404, detail=f"User {user_id} not found")
    return user


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete user")
def delete_user(user_id: int, db: Session = Depends(get_db)) -> None:
    if not crud.delete_user(db, user_id):
        raise HTTPException(status_code=404, detail=f"User {user_id} not found")
