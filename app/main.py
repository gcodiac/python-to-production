from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles

from app.database import get_connection
from app.models import Note, NoteCreate, NoteUpdate

app = FastAPI(title="Minimal Notes API")


@app.get("/notes", response_model=list[Note])
def list_notes():
    connection = get_connection()
    try:
        rows = connection.execute("SELECT * FROM notes ORDER BY id").fetchall()
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
            raise HTTPException(status_code=404, detail="Note not found")
        return dict(row)
    finally:
        connection.close()
