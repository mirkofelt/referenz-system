from fastapi.testclient import TestClient
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from main import app

client = TestClient(app)


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_embed_returns_vector():
    r = client.post("/embed", json={"text": "Wärmedämmung Neubau"})
    assert r.status_code == 200
    data = r.json()
    assert "embedding" in data
    assert len(data["embedding"]) == 384
    assert all(isinstance(v, float) for v in data["embedding"])


def test_embed_batch():
    r = client.post("/embed/batch", json={"texts": ["Text A", "Text B"]})
    assert r.status_code == 200
    data = r.json()
    assert len(data["embeddings"]) == 2
    assert len(data["embeddings"][0]) == 384


def test_embed_empty_string():
    r = client.post("/embed", json={"text": ""})
    assert r.status_code == 200
    assert len(r.json()["embedding"]) == 384


def test_embed_batch_single():
    r = client.post("/embed/batch", json={"texts": ["Einzelner Text"]})
    assert r.status_code == 200
    assert len(r.json()["embeddings"]) == 1
