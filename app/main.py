import logging
from pathlib import Path
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text
from sqlalchemy.engine import Connection

from app.config import APP_ENV, APP_HOST, APP_PORT, LOG_LEVEL
from app.database import (
    DatabaseUnavailableError,
    database_backend,
    get_connection,
    insert_note,
    notes,
)
from app.models import Note, NoteCreate, NoteUpdate

logging.basicConfig(level=LOG_LEVEL)
logger = logging.getLogger(__name__)

app = FastAPI(title="Minimal Notes API")

NOTE_NOT_FOUND = "Note not found"
MAX_NOTES_RETURNED = 500

# Every sort option maps to a column expression, not to a fragment of SQL
# text. User input selects an entry from this dictionary and can do nothing
# else - there is no runtime string-building of SQL anywhere in this module,
# so there is nothing for user input to inject into.
_NOTE_SORTS = {
    "id": notes.c.id,
    "title": notes.c.title,
    "created_at": notes.c.created_at,
    "id_desc": notes.c.id.desc(),
    "title_desc": notes.c.title.desc(),
    "created_at_desc": notes.c.created_at.desc(),
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


# A SQLAlchemy Connection, whichever backend it happens to be talking to.
# The endpoints below never learn which one that is.
DbConnection = Annotated[Connection, Depends(get_db)]


def _row_to_note(row) -> dict:
    """Turn a result row into the plain dict the response model expects.

    `row._mapping` is SQLAlchemy's documented column-name view of a row; the
    leading underscore marks it as part of the Row namespace rather than a
    column named "mapping".
    """
    return dict(row._mapping)


@app.get("/notes", response_model=list[Note])
def list_notes(connection: DbConnection, sort: str = "id"):
    order_by = _NOTE_SORTS.get(sort, _NOTE_SORTS["id"])
    rows = connection.execute(
        notes.select().order_by(order_by).limit(MAX_NOTES_RETURNED)
    ).all()
    return [_row_to_note(row) for row in rows]


@app.post("/notes", response_model=Note, status_code=201)
def create_note(note: NoteCreate, connection: DbConnection):
    return insert_note(connection, note.title, note.content)


@app.get("/notes/{note_id}", response_model=Note)
def get_note(note_id: int, connection: DbConnection):
    row = connection.execute(notes.select().where(notes.c.id == note_id)).first()
    if row is None:
        raise HTTPException(status_code=404, detail=NOTE_NOT_FOUND)
    return _row_to_note(row)


@app.put("/notes/{note_id}", response_model=Note)
def update_note(note_id: int, note: NoteUpdate, connection: DbConnection):
    existing = connection.execute(notes.select().where(notes.c.id == note_id)).first()
    if existing is None:
        raise HTTPException(status_code=404, detail=NOTE_NOT_FOUND)
    connection.execute(
        notes.update()
        .where(notes.c.id == note_id)
        .values(title=note.title, content=note.content)
    )
    connection.commit()
    row = connection.execute(notes.select().where(notes.c.id == note_id)).one()
    return _row_to_note(row)


@app.delete("/notes/{note_id}", status_code=204)
def delete_note(note_id: int, connection: DbConnection):
    existing = connection.execute(notes.select().where(notes.c.id == note_id)).first()
    if existing is None:
        raise HTTPException(status_code=404, detail=NOTE_NOT_FOUND)
    connection.execute(notes.delete().where(notes.c.id == note_id))
    connection.commit()


@app.get("/health")
def health_check():
    """Liveness: is this process alive and serving HTTP?

    Deliberately does NOT touch the database. A liveness check that fails
    during a transient database outage would tell an orchestrator to restart
    a perfectly healthy process, turning a brief database blip into a crash
    loop - see devops-learning/11-health-checks-and-service-readiness.md.
    """
    return {"status": "ok", "environment": APP_ENV}


@app.get("/ready")
def readiness_check():
    """Readiness: can this instance actually serve requests right now?

    Unlike /health, this does check the database, because an instance that
    cannot reach its database should be taken out of a load balancer's
    rotation - without being restarted.
    """
    try:
        connection = get_connection()
    except DatabaseUnavailableError as exc:
        logger.warning("Readiness check failed: %s", exc)
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    try:
        connection.execute(text("SELECT 1"))
    finally:
        connection.close()
    return {"status": "ready", "database": database_backend()}


STATIC_DIR = Path(__file__).parent / "static"
app.mount("/", StaticFiles(directory=STATIC_DIR, html=True), name="dashboard")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=APP_HOST, port=APP_PORT)
