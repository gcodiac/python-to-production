import logging
import sqlite3
from pathlib import Path
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles

from app.config import APP_ENV, APP_HOST, APP_PORT, LOG_LEVEL
from app.database import DatabaseUnavailableError, get_connection
from app.models import Note, NoteCreate, NoteUpdate

logging.basicConfig(level=LOG_LEVEL)
logger = logging.getLogger(__name__)

app = FastAPI(title="Minimal Notes API")

NOTE_NOT_FOUND = "Note not found"
MAX_NOTES_RETURNED = 500

# Every sort option maps to a complete, static query string - there is no
# runtime string-building of SQL here, so there's nothing for user input to
# inject into.
_NOTE_QUERIES = {
    "id": "SELECT * FROM notes ORDER BY id LIMIT ?",
    "title": "SELECT * FROM notes ORDER BY title LIMIT ?",
    "created_at": "SELECT * FROM notes ORDER BY created_at LIMIT ?",
    "id_desc": "SELECT * FROM notes ORDER BY id DESC LIMIT ?",
    "title_desc": "SELECT * FROM notes ORDER BY title DESC LIMIT ?",
    "created_at_desc": "SELECT * FROM notes ORDER BY created_at DESC LIMIT ?",
}


def get_db():
    """FastAPI dependency yielding a database connection, closed after the request.

    Centralising connection acquisition/cleanup here means every endpoint
    below just declares a `DbConnection` parameter instead of repeating the
    same acquire/try/finally-close block five times. It also means a
    database failure produces one clear, understandable 503 response instead
    of an unhandled 500 traceback leaking out of whichever endpoint happened
    to touch the database first.
    """
    try:
        connection = get_connection()
    except DatabaseUnavailableError as exc:
        logger.error("Database unavailable: %s", exc)
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    try:
        yield connection
    finally:
        connection.close()


DbConnection = Annotated[sqlite3.Connection, Depends(get_db)]


@app.get("/notes", response_model=list[Note])
def list_notes(connection: DbConnection, sort: str = "id"):
    query = _NOTE_QUERIES.get(sort, _NOTE_QUERIES["id"])
    rows = connection.execute(query, (MAX_NOTES_RETURNED,)).fetchall()
    return [dict(row) for row in rows]


@app.post("/notes", response_model=Note, status_code=201)
def create_note(note: NoteCreate, connection: DbConnection):
    cursor = connection.execute(
        "INSERT INTO notes (title, content) VALUES (?, ?)",
        (note.title, note.content),
    )
    connection.commit()
    row = connection.execute(
        "SELECT * FROM notes WHERE id = ?", (cursor.lastrowid,)
    ).fetchone()
    return dict(row)


@app.get("/notes/{note_id}", response_model=Note)
def get_note(note_id: int, connection: DbConnection):
    row = connection.execute("SELECT * FROM notes WHERE id = ?", (note_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail=NOTE_NOT_FOUND)
    return dict(row)


@app.put("/notes/{note_id}", response_model=Note)
def update_note(note_id: int, note: NoteUpdate, connection: DbConnection):
    existing = connection.execute("SELECT * FROM notes WHERE id = ?", (note_id,)).fetchone()
    if existing is None:
        raise HTTPException(status_code=404, detail=NOTE_NOT_FOUND)
    connection.execute(
        "UPDATE notes SET title = ?, content = ? WHERE id = ?",
        (note.title, note.content, note_id),
    )
    connection.commit()
    row = connection.execute("SELECT * FROM notes WHERE id = ?", (note_id,)).fetchone()
    return dict(row)


@app.delete("/notes/{note_id}", status_code=204)
def delete_note(note_id: int, connection: DbConnection):
    existing = connection.execute("SELECT * FROM notes WHERE id = ?", (note_id,)).fetchone()
    if existing is None:
        raise HTTPException(status_code=404, detail=NOTE_NOT_FOUND)
    connection.execute("DELETE FROM notes WHERE id = ?", (note_id,))
    connection.commit()


@app.get("/health")
def health_check():
    """Basic liveness/readiness signal for load balancers, orchestrators, etc."""
    return {"status": "ok", "environment": APP_ENV}


STATIC_DIR = Path(__file__).parent / "static"
app.mount("/", StaticFiles(directory=STATIC_DIR, html=True), name="dashboard")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=APP_HOST, port=APP_PORT)
