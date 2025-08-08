# app/db/mongo.py

from pymongo import MongoClient
import os

MONGO_URL = os.getenv("MONGO_URL", "mongodb://localhost:27017")
client = MongoClient(MONGO_URL)
db = client["mydatabase"]
items_collection = db["items"]
