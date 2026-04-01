from fastapi.testclient import TestClient


def test_liveness(client: TestClient):
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.json()["status"] == "alive"


def test_readiness(client: TestClient):
    # SQLite in-memory is always reachable — should return ready
    r = client.get("/readyz")
    assert r.status_code == 200
    assert r.json()["status"] == "ready"
