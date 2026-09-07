import os
import sqlite3

DB_PATH = os.environ.get("NOTES_DB_PATH", "notes.db")

# TRAINING-ISSUE: Hard-coded configuration should be moved into environment
# variables. This constant isn't even wired up to the connection below (which
# correctly reads NOTES_DB_PATH) - it's the kind of leftover, inconsistent
# configuration a learner should find and clean up.
DATABASE_URL = "sqlite:///./notes.db"

SCHEMA = """
CREATE TABLE IF NOT EXISTS notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
"""


def get_connection() -> sqlite3.Connection:
    connection = sqlite3.connect(DB_PATH)
    connection.row_factory = sqlite3.Row
    connection.execute(SCHEMA)
    return connection
