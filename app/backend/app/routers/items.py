"""
Items CRUD router — mounted at /api/v1/items.
Uses SQLAlchemy session via FastAPI's Depends(get_db) dependency injection.

DEPENDENCY INJECTION PATTERN:
  FastAPI calls get_db() before the route handler, passes the session as `db`.
  After the handler returns, FastAPI calls the finally block in get_db() to close it.
  This means every request gets its own isolated session — no shared state between requests.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app import crud
from app.database import get_db
from app.models import Item, ItemCreate, ItemUpdate

router = APIRouter(prefix="/items", tags=["items"])


@router.get("/", response_model=list[Item], summary="List all items")
def list_items(db: Session = Depends(get_db)) -> list:
    return crud.get_items(db)


@router.post("/", response_model=Item, status_code=status.HTTP_201_CREATED, summary="Create item")
def create_item(payload: ItemCreate, db: Session = Depends(get_db)) -> object:
    return crud.create_item(db, **payload.model_dump())


@router.get("/{item_id}", response_model=Item, summary="Get item by ID")
def get_item(item_id: int, db: Session = Depends(get_db)) -> object:
    item = crud.get_item(db, item_id)
    if not item:
        raise HTTPException(status_code=404, detail=f"Item {item_id} not found")
    return item


@router.put("/{item_id}", response_model=Item, summary="Update item")
def update_item(item_id: int, payload: ItemUpdate, db: Session = Depends(get_db)) -> object:
    item = crud.update_item(db, item_id, **payload.model_dump())
    if not item:
        raise HTTPException(status_code=404, detail=f"Item {item_id} not found")
    return item


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete item")
def delete_item(item_id: int, db: Session = Depends(get_db)) -> None:
    if not crud.delete_item(db, item_id):
        raise HTTPException(status_code=404, detail=f"Item {item_id} not found")
