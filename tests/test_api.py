from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_check():
    response = client.get("/health", timeout=5)
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}

def test_create_and_get_items():
    item_data = {"name": "Test Item", "description": "A test item"}
    
    post_response = client.post("/items", json=item_data, timeout=5)
    assert post_response.status_code == 200
    assert post_response.json() == item_data

    get_response = client.get("/items", timeout=5)
    assert get_response.status_code == 200
    assert any(i["name"] == "Test Item" for i in get_response.json())
