# app/auth.py
from datetime import datetime, timedelta
from typing import Optional

import jwt
from jwt import InvalidTokenError, ExpiredSignatureError
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel

from app.core.config import settings
from app.db.mongo import users_collection  # lecture des users en DB

# Config
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Security helpers
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Schemas
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None

class User(BaseModel):
    username: str
    full_name: Optional[str] = None


# Password utils
def hash_password(plain: str) -> str:
    return pwd_context.hash(plain)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


# DB helpers
def get_user(username: str) -> Optional[User]:
    doc = users_collection.find_one({"username": username})
    if not doc:
        return None
    return User(username=doc["username"], full_name=doc.get("full_name"))

def authenticate_user(username: str, password: str) -> Optional[User]:
    doc = users_collection.find_one({"username": username})
    if not doc:
        return None
    if not verify_password(password, doc["hashed_password"]):
        return None
    return User(username=doc["username"], full_name=doc.get("full_name"))


# JWT helpers
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """
    Génère un JWT signé HS256 avec un 'sub' (username) dans `data`
    et une date d'expiration (exp).
    """
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    # PyJWT 2.x renvoie déjà une str
    token = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=ALGORITHM)
    return token


# Dependency
async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid token",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
        username: Optional[str] = payload.get("sub")
        if not username:
            raise credentials_exception
    except (ExpiredSignatureError, InvalidTokenError):
        # token expiré ou invalide
        raise credentials_exception

    user = get_user(username)
    if not user:
        raise credentials_exception
    return user
