import os
from dotenv import load_dotenv

load_dotenv()  # charge .env à partir de la racine du projet

class Settings:
    MONGO_URL: str = os.getenv("MONGO_URL", "mongodb://localhost:27017")
    DATABASE_NAME: str = os.getenv("DATABASE_NAME", "mydatabase")
    SECRET_KEY: str = os.getenv("SECRET_KEY", "mysecret")

settings = Settings()
