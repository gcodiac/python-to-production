import os
import tempfile

os.environ["NOTES_DB_PATH"] = tempfile.NamedTemporaryFile(suffix=".db", delete=False).name

import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


@pytest.fixture(autouse=True)
def reset_database():
    import app.database as database

    connection = database.get_connection()
    connection.execute("DELETE FROM notes")
    connection.commit()
    connection.close()
    yield


def test_create_note():
    response = client.post("/notes", json={"title": "Groceries", "content": "Milk, eggs"})
    assert response.status_code == 201
    body = response.json()
    assert body["title"] == "Groceries"
    assert body["content"] == "Milk, eggs"
    assert "id" in body


def test_list_notes_empty():
    response = client.get("/notes")
    assert response.status_code == 200
    assert response.json() == []


def test_get_note_not_found():
    response = client.get("/notes/999")
    assert response.status_code == 404


def test_update_and_get_note():
    created = client.post("/notes", json={"title": "Old", "content": "old content"}).json()
    note_id = created["id"]

    response = client.put(
        f"/notes/{note_id}", json={"title": "New", "content": "new content"}
    )
    assert response.status_code == 200
    assert response.json()["title"] == "New"

    fetched = client.get(f"/notes/{note_id}")
    assert fetched.json()["title"] == "New"


def test_delete_note():
    created = client.post("/notes", json={"title": "Temp", "content": ""}).json()
    note_id = created["id"]

    response = client.delete(f"/notes/{note_id}")
    assert response.status_code == 204

    fetched = client.get(f"/notes/{note_id}")
    assert fetched.status_code == 404


def test_health_does_not_touch_the_database():
    """Liveness must not depend on the database.

    A liveness probe that fails during a database blip would make Kubernetes
    restart healthy Pods - see cloud-learning/13.
    """
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_ready_reports_the_active_backend():
    """Readiness does check the database, and names the backend in use."""
    response = client.get("/ready")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    # Tests run against SQLite; AWS staging reports "postgres" here instead.
    assert body["database"] == "sqlite"


def test_postgres_adapter_translates_placeholders():
    """The PostgreSQL adapter rewrites SQLite's `?` to psycopg's `%s`.

    Unit-level so it runs in CI without a live PostgreSQL server.
    """
    from app.database import _PostgresConnection

    translated = _PostgresConnection._translate(
        "SELECT * FROM notes WHERE id = ? AND title = ?"
    )
    assert translated == "SELECT * FROM notes WHERE id = %s AND title = %s"
