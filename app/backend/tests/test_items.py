from fastapi.testclient import TestClient


def test_list_items_empty(client: TestClient):
    r = client.get("/api/v1/items/")
    assert r.status_code == 200
    assert r.json() == []


def test_create_item(client: TestClient):
    r = client.post("/api/v1/items/", json={"name": "Widget", "description": "desc", "price": 9.99})
    assert r.status_code == 201
    data = r.json()
    assert data["name"] == "Widget"
    assert data["price"] == 9.99
    assert "id" in data
    assert "created_at" in data


def test_list_items_after_create(client: TestClient):
    client.post("/api/v1/items/", json={"name": "A", "price": 1.0})
    client.post("/api/v1/items/", json={"name": "B", "price": 2.0})
    r = client.get("/api/v1/items/")
    assert r.status_code == 200
    assert len(r.json()) == 2


def test_get_item(client: TestClient):
    created = client.post("/api/v1/items/", json={"name": "Thing", "price": 5.0}).json()
    r = client.get(f"/api/v1/items/{created['id']}")
    assert r.status_code == 200
    assert r.json()["name"] == "Thing"


def test_get_item_not_found(client: TestClient):
    r = client.get("/api/v1/items/9999")
    assert r.status_code == 404


def test_update_item(client: TestClient):
    created = client.post("/api/v1/items/", json={"name": "Old", "price": 1.0}).json()
    r = client.put(f"/api/v1/items/{created['id']}", json={"price": 99.99})
    assert r.status_code == 200
    assert r.json()["price"] == 99.99
    assert r.json()["name"] == "Old"  # unchanged


def test_delete_item(client: TestClient):
    created = client.post("/api/v1/items/", json={"name": "ToDelete", "price": 0.01}).json()
    r = client.delete(f"/api/v1/items/{created['id']}")
    assert r.status_code == 204
    assert client.get(f"/api/v1/items/{created['id']}").status_code == 404


def test_delete_item_not_found(client: TestClient):
    r = client.delete("/api/v1/items/9999")
    assert r.status_code == 404
