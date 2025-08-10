from fastapi.testclient import TestClient
from app.main import app
from app.db import users_collection, items_collection

client = TestClient(app)

TEST_USER = {
    "username": "testuser",
    "password": "testpassword"
}

def create_test_user():
    # Simule l'enregistrement de l'utilisateur
    response = client.post("/register", json=TEST_USER)
    assert response.status_code == 200

def delete_test_user():
    users_collection.delete_one({"username": TEST_USER["username"]})

def get_auth_headers():
    response = client.post("/token", data=TEST_USER)
    assert response.status_code == 200
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}

def test_full_oauth_flow():
    # Cleanup avant
    delete_test_user()
    items_collection.delete_many({"name": "OAuth Item"})

    # 1. Création de l'utilisateur
    create_test_user()

    # 2. Authentification et récupération du token
    headers = get_auth_headers()

    # 3. Utilisation du token pour accéder aux routes sécurisées
    item_data = {"name": "OAuth Item", "description": "Created via test"}
    response = client.post("/items", json=item_data, headers=headers)
    assert response.status_code == 200
    assert response.json() == item_data

    # 4. Lecture des items
    response = client.get("/items", headers=headers)
    assert response.status_code == 200
    items = response.json()
    assert any(item["name"] == "OAuth Item" for item in items)

    # 5. Nettoyage après test
    items_collection.delete_many({"name": "OAuth Item"})
    delete_test_user()
