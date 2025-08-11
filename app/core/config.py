# app/core/config.py
import os

class Settings:
    MONGO_URL: str = os.getenv("MONGO_URL", "mongodb://mongo-service:27017")
    DATABASE_NAME: str = os.getenv("DATABASE_NAME", "mydatabase")
    SECRET_KEY: str = os.getenv("SECRET_KEY", "change-me-in-k8s")

settings = Settings()
