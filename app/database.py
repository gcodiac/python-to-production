import sqlite3

from app.config import DB_PATH

SCHEMA = """
CREATE TABLE IF NOT EXISTS notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
"""


class DatabaseUnavailableError(RuntimeError):
    """Raised when the configured database cannot be opened.

    Translating the low-level sqlite3 error here keeps callers (app/main.py)
    from needing to know anything about sqlite3 specifically.
    """


def get_connection() -> sqlite3.Connection:
    try:
        connection = sqlite3.connect(DB_PATH)
        connection.row_factory = sqlite3.Row
        connection.execute(SCHEMA)
    except sqlite3.OperationalError as exc:
        raise DatabaseUnavailableError(f"Could not open database at {DB_PATH!r}: {exc}") from exc
    return connection
