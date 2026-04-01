from fastapi.testclient import TestClient


def test_metrics_empty_db(client: TestClient):
    r = client.get("/api/v1/metrics/")
    assert r.status_code == 200
    data = r.json()
    assert data["items_count"] == 0
    assert data["users_count"] == 0


def test_metrics_reflects_data(client: TestClient):
    client.post("/api/v1/items/", json={"name": "A", "price": 1.0})
    client.post("/api/v1/items/", json={"name": "B", "price": 2.0})
    client.post("/api/v1/users/", json={"username": "user1", "email": "user1@test.com"})

    r = client.get("/api/v1/metrics/")
    assert r.status_code == 200
    assert r.json()["items_count"] == 2
    assert r.json()["users_count"] == 1
