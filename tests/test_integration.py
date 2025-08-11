# tests/test_integration_auth_and_health.py
import os
import time
import uuid
import pytest
from fastapi.testclient import TestClient

# Marque ce fichier comme "integration"
pytestmark = pytest.mark.integration

# ==== Imports de ton app (adaptés à ton projet) ====
from app.main import app
from app.db.mongo import client as mongo_client, db as mongo_db, users_collection
from app.auth import hash_password


@pytest.fixture(scope="session")
def client():
    # Démarre l'app FastAPI dans le process de test
    return TestClient(app)


@pytest.fixture(scope="session", autouse=True)
def wait_for_mongo():
    """Attend que Mongo soit prêt (utile en CI)."""
    url = os.environ.get("MONGO_URL", "mongodb://localhost:27017")
    timeout_s = 20
    start = time.time()
    last_err = None
    while time.time() - start < timeout_s:
        try:
            mongo_client.admin.command("ping")
            return
        except Exception as e:
            last_err = e
            time.sleep(0.5)
    pytest.skip(f"MongoDB pas prêt à {url}: {last_err}")


@pytest.fixture
def test_user():
    """Crée un utilisateur jetable dans la collection users."""
    username = f"it-{uuid.uuid4().hex[:8]}"
    password = "P@ssw0rd!"
    doc = {
        "username": username,
        "full_name": "Integration Tester",
        "hashed_password": hash_password(password),
    }
    users_collection.insert_one(doc)
    try:
        yield {"username": username, "password": password}
    finally:
        users_collection.delete_one({"username": username})


def get_token(client: TestClient, username: str, password: str) -> str:
    # Ton endpoint OAuth2 standard attend du form-urlencoded:
    data = {
        "grant_type": "password",
        "username": username,
        "password": password,
    }
    r = client.post("/token", data=data)
    assert r.status_code == 200, r.text
    body = r.json()
    assert "access_token" in body and body.get("token_type") == "bearer"
    return body["access_token"]


def test_health_ok(client: TestClient):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() in ({"status": "ok"}, {"ok": True})  # au choix selon ton implémentation


def test_oauth_token_ok(client: TestClient, test_user):
    token = get_token(client, test_user["username"], test_user["password"])
    assert isinstance(token, str) and len(token) > 10

    # Exemple d’appel protégé si tu as un endpoint /items ou /users/me :
    # headers = {"Authorization": f"Bearer {token}"}
    # r = client.get("/users/me", headers=headers)
    # assert r.status_code == 200
    # assert r.json()["username"] == test_user["username"]

    # Si tu veux tester un CRUD "items", adapte le payload/champs à ton schéma :
    # item = {"name": "Widget"}  # <-- mets tes vrais champs ici
    # r = client.post("/items", json=item, headers=headers)
    # assert r.status_code in (200, 201)
    # item_id = r.json().get("id") or r.json().get("_id")
    # assert item_id
