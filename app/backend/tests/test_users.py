from fastapi.testclient import TestClient


def test_list_users_empty(client: TestClient):
    r = client.get("/api/v1/users/")
    assert r.status_code == 200
    assert r.json() == []


def test_create_user(client: TestClient):
    r = client.post("/api/v1/users/", json={"username": "ahmed", "email": "ahmed@test.com"})
    assert r.status_code == 201
    data = r.json()
    assert data["username"] == "ahmed"
    assert data["email"] == "ahmed@test.com"
    assert "id" in data


def test_get_user(client: TestClient):
    created = client.post("/api/v1/users/", json={"username": "bob", "email": "bob@test.com"}).json()
    r = client.get(f"/api/v1/users/{created['id']}")
    assert r.status_code == 200
    assert r.json()["username"] == "bob"


def test_get_user_not_found(client: TestClient):
    r = client.get("/api/v1/users/9999")
    assert r.status_code == 404


def test_update_user(client: TestClient):
    created = client.post("/api/v1/users/", json={"username": "alice", "email": "alice@test.com"}).json()
    r = client.put(f"/api/v1/users/{created['id']}", json={"email": "new@test.com"})
    assert r.status_code == 200
    assert r.json()["email"] == "new@test.com"
    assert r.json()["username"] == "alice"  # unchanged


def test_delete_user(client: TestClient):
    created = client.post("/api/v1/users/", json={"username": "todel", "email": "del@test.com"}).json()
    r = client.delete(f"/api/v1/users/{created['id']}")
    assert r.status_code == 204
    assert client.get(f"/api/v1/users/{created['id']}").status_code == 404


def test_delete_user_not_found(client: TestClient):
    r = client.delete("/api/v1/users/9999")
    assert r.status_code == 404
