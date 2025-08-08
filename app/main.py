from fastapi import FastAPI
from pymongo import MongoClient
import os

app = FastAPI()

@app.get("/health")
def health_check():
    return {"status": "ok"}
