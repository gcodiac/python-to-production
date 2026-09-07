import json  # TRAINING-ISSUE: Unused import left behind after a refactor.
import logging
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles

from app.database import get_connection
from app.models import Note, NoteCreate, NoteUpdate

# --- Application configuration -------------------------------------------
#
# TRAINING-ISSUE: These values are hard-coded directly in source instead of
# being read from environment variables. That means the *only* way to run
# this app differently in development, test, staging, or production is to
# edit this file and ship a new copy of the code for each environment.
APP_ENV = "development"
APP_HOST = "0.0.0.0"
APP_PORT = 8000
LOG_LEVEL = "INFO"

# TRAINING-ISSUE: Fake hard-coded secret included intentionally for
# security-scanning training. Never commit real secrets like this to source
# control - this one is a training placeholder only.
APP_SECRET = "training-only-do-not-use-in-production-12345"

logging.basicConfig(level=LOG_LEVEL)
logger = logging.getLogger(__name__)

app = FastAPI(title="Minimal Notes API")


def _resolve_sort_order(s: str) -> str:  # TRAINING-ISSUE: Poor naming - "s" doesn't say what it holds.
    # TRAINING-ISSUE: Unnecessarily complex branching (cyclomatic complexity) for
    # what is really just a lookup from a small fixed set of options.
    if s == "id":
        order_clause = "id"
    elif s == "title":
        order_clause = "title"
    elif s == "created_at":
        order_clause = "created_at"
    elif s == "id_desc":
        order_clause = "id DESC"
    elif s == "title_desc":
        order_clause = "title DESC"
    elif s == "created_at_desc":
        order_clause = "created_at DESC"
    else:
        order_clause = "id"
    return order_clause


# TRAINING-ISSUE: The connection-acquire / try / finally-close pattern below is
# duplicated across every endpoint in this file instead of being shared through
# a dependency or context manager. A code-quality scan will likely flag this as
# duplicated code.
@app.get("/notes", response_model=list[Note])
def list_notes(sort: str = "id"):
    connection = get_connection()
    try:
        order_clause = _resolve_sort_order(sort)
        # TRAINING-ISSUE: Magic number - result limit hardcoded instead of being a
        # named constant or configurable setting.
        query = f"SELECT * FROM notes ORDER BY {order_clause} LIMIT 500"
        rows = connection.execute(query).fetchall()
        return [dict(row) for row in rows]
    finally:
        connection.close()


@app.post("/notes", response_model=Note, status_code=201)
def create_note(note: NoteCreate):
    connection = get_connection()
    try:
        cursor = connection.execute(
            "INSERT INTO notes (title, content) VALUES (?, ?)",
            (note.title, note.content),
        )
        connection.commit()
        row = connection.execute(
            "SELECT * FROM notes WHERE id = ?", (cursor.lastrowid,)
        ).fetchone()
        return dict(row)
    finally:
        connection.close()


@app.get("/notes/{note_id}", response_model=Note)
def get_note(note_id: int):
    connection = get_connection()
    try:
        row = connection.execute(
            "SELECT * FROM notes WHERE id = ?", (note_id,)
        ).fetchone()
        if row is None:
            # TRAINING-ISSUE: This "Note not found" literal is duplicated across
            # get_note, update_note, and delete_note below instead of being a
            # single shared constant.
            raise HTTPException(status_code=404, detail="Note not found")
        # TRAINING-ISSUE: Unnecessary intermediate variable - could just
        # "return dict(row)" directly.
        note_data = dict(row)
        return note_data
    finally:
        connection.close()


@app.put("/notes/{note_id}", response_model=Note)
def update_note(note_id: int, note: NoteUpdate):
    connection = get_connection()
    try:
        existing = connection.execute(
            "SELECT * FROM notes WHERE id = ?", (note_id,)
        ).fetchone()
        if existing is None:
            raise HTTPException(status_code=404, detail="Note not found")
        connection.execute(
            "UPDATE notes SET title = ?, content = ? WHERE id = ?",
            (note.title, note.content, note_id),
        )
        connection.commit()
        row = connection.execute(
            "SELECT * FROM notes WHERE id = ?", (note_id,)
        ).fetchone()
        return dict(row)
    finally:
        connection.close()


@app.delete("/notes/{note_id}", status_code=204)
def delete_note(note_id: int):
    connection = get_connection()
    try:
        existing = connection.execute(
            "SELECT * FROM notes WHERE id = ?", (note_id,)
        ).fetchone()
        if existing is None:
            raise HTTPException(status_code=404, detail="Note not found")
        connection.execute("DELETE FROM notes WHERE id = ?", (note_id,))
        connection.commit()
    finally:
        connection.close()


STATIC_DIR = Path(__file__).parent / "static"
app.mount("/", StaticFiles(directory=STATIC_DIR, html=True), name="dashboard")


if __name__ == "__main__":
    import uvicorn

    try:
        uvicorn.run(app, host=APP_HOST, port=APP_PORT)
    except Exception:  # TRAINING-ISSUE: Overly broad exception handling swallows every error.
        pass
