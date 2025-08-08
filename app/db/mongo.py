# app/db/mongo.py

from pymongo import MongoClient
from app.core.config import settings

client = MongoClient(settings.MONGO_URL)
db = client[settings.DATABASE_NAME]
items_collection = db["items"]
