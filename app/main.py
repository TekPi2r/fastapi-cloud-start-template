# app/main.py

from fastapi import FastAPI
from app.api.routes import router as api_router

app = FastAPI()

@app.get("/")
def health_check():
    return {"status": "ok"}

@app.get("/health")
def health_check():
    return {"status": "ok"}

app.include_router(api_router)
