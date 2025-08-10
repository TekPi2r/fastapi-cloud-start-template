# tests/test_api.py
import os
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.db.mongo import users_collection, items_collection

# Forcer une conf locale de test si besoin
os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DATABASE_NAME", "mydatabase")

client = TestClient(app)

TEST_USER = {"username": "testuser", "password": "testpassword", "full_name": "Tester"}
TEST_ITEM = {"name": "OAuth Item", "description": "Created via test"}

@pytest.fixture(autouse=True)
def clean_db():
    # Avant chaque test
    users_collection.delete_one({"username": TEST_USER["username"]})
    items_collection.delete_many({"name": TEST_ITEM["name"]})
    yield
    # Après chaque test
    users_collection.delete_one({"username": TEST_USER["username"]})
    items_collection.delete_many({"name": TEST_ITEM["name"]})

def get_auth_headers():
    # 1) register
    r = client.post("/register", json=TEST_USER)
    assert r.status_code in (200, 400)  # 400 si déjà créé
    # 2) login (x-www-form-urlencoded)
    login_data = {"username": TEST_USER["username"], "password": TEST_USER["password"]}
    token_resp = client.post("/token", data=login_data)
    assert token_resp.status_code == 200
    token = token_resp.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}

def test_health_check():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}

def test_full_oauth_and_items_crud():
    headers = get_auth_headers()

    # create
    r = client.post("/items", json=TEST_ITEM, headers=headers)
    assert r.status_code == 200
    assert r.json() == TEST_ITEM

    # list
    r = client.get("/items", headers=headers)
    assert r.status_code == 200
    items = r.json()
    assert any(i["name"] == TEST_ITEM["name"] for i in items)
