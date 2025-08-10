from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel
from typing import List
from datetime import timedelta

from app.db.mongo import items_collection, users_collection
from app.auth import (
    Token, User, authenticate_user, create_access_token,
    get_current_user, ACCESS_TOKEN_EXPIRE_MINUTES, hash_password
)

router = APIRouter()

class RegisterIn(BaseModel):
    username: str
    password: str
    full_name: str | None = None

class Item(BaseModel):
    name: str
    description: str

@router.get("/health")
def health_check():
    return {"status": "ok"}

@router.post("/register")
def register_user(payload: RegisterIn):
    if users_collection.find_one({"username": payload.username}):
        raise HTTPException(status_code=400, detail="User already exists")
    users_collection.insert_one({
        "username": payload.username,
        "full_name": payload.full_name,
        "hashed_password": hash_password(payload.password),
    })
    return {"ok": True, "username": payload.username}

@router.post("/token", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends()):
    user = authenticate_user(form_data.username, form_data.password)
    if not user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST,
                            detail="Incorrect username or password")
    access_token = create_access_token(
        data={"sub": user.username},
        expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES),
    )
    return {"access_token": access_token, "token_type": "bearer"}

@router.post("/items", response_model=Item)
def create_item(item: Item, current_user: User = Depends(get_current_user)):
    items_collection.insert_one(item.model_dump())
    return item

@router.get("/items", response_model=List[Item])
def list_items(current_user: User = Depends(get_current_user)):
    return list(items_collection.find({}, {"_id": 0}))
