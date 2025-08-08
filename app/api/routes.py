# app/api/routes.py

from fastapi import APIRouter
from pydantic import BaseModel
from typing import List
from app.db.mongo import items_collection

router = APIRouter()

class Item(BaseModel):
    name: str
    description: str

@router.post("/items", response_model=Item)
def create_item(item: Item):
    items_collection.insert_one(item.dict())
    return item

@router.get("/items", response_model=List[Item])
def list_items():
    items = list(items_collection.find({}, {"_id": 0}))  # hide MongoDB internal _id
    return items
