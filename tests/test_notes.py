import os
import tempfile

# Point the application at a throwaway SQLite file *before* importing it, so
# the test run never touches a developer's real notes.db.
#
# setdefault, not assignment: if DATABASE_URL is already set, whoever set it
# wins. That is how CI runs this exact suite a second time against a real
# PostgreSQL server without maintaining a separate copy of these tests - see
# cicd-learning/04-verifying-database-portability-in-ci.md.
_TEST_DB_DIR = tempfile.mkdtemp(prefix="notes-tests-")
os.environ.setdefault("DATABASE_URL", f"sqlite:///{_TEST_DB_DIR}/notes.db")

import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


@pytest.fixture(autouse=True)
def reset_database():
    from app import database

    connection = database.get_connection()
    connection.execute(database.notes.delete())
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
