"""Storage layer.

Two backends, one codebase - see cloud-learning/10-rds-postgresql-and-persistent-data.md:

    local development   -> SQLite   (unchanged from Stages 1-3)
    AWS staging         -> RDS PostgreSQL

Which one is used is purely a configuration decision (`DB_HOST` set or not),
never a code or image decision. The SQLite path below is byte-for-byte the
behaviour earlier stages shipped; PostgreSQL support is added alongside it.
"""

import sqlite3

from app import config

SCHEMA_SQLITE = """
CREATE TABLE IF NOT EXISTS notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
"""

# PostgreSQL equivalent. Differences are deliberate, not accidental:
#   - IDENTITY instead of AUTOINCREMENT (the SQL-standard spelling)
#   - TEXT created_at written by the database, so both backends return the
#     same "YYYY-MM-DD HH:MM:SS" string shape the Note model expects.
SCHEMA_POSTGRES = """
CREATE TABLE IF NOT EXISTS notes (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT to_char(now(), 'YYYY-MM-DD HH24:MI:SS')
);
"""


class DatabaseUnavailableError(RuntimeError):
    """Raised when the configured database cannot be reached.

    Translating the low-level driver error here keeps callers (app/main.py)
    from needing to know whether SQLite or PostgreSQL is in use.
    """


class _PostgresConnection:
    """Thin adapter making psycopg behave like the sqlite3 API this app uses.

    The application's SQL is written once, with SQLite's `?` placeholders.
    Rather than duplicating every query per backend, this adapter translates
    `?` to psycopg's `%s` and returns dict-like rows, so `dict(row)` works
    identically on both backends.
    """

    def __init__(self, connection):
        self._connection = connection

    @staticmethod
    def _translate(sql: str) -> str:
        return sql.replace("?", "%s")

    def execute(self, sql: str, params: tuple = ()):
        cursor = self._connection.cursor()
        cursor.execute(self._translate(sql), params)
        return cursor

    def commit(self) -> None:
        self._connection.commit()

    def close(self) -> None:
        self._connection.close()


def _connect_postgres():
    """Connect to PostgreSQL using keyword arguments, never a built-up URL.

    Passing host/user/password as separate keyword arguments means a password
    containing `@`, `/`, `:` or any other URL-reserved character needs no
    escaping and cannot corrupt the connection details - a real class of bug
    that naive f-string URL building introduces.
    """
    import psycopg
    from psycopg.rows import dict_row

    password = config.read_db_password()
    if not password:
        raise DatabaseUnavailableError(
            "PostgreSQL is configured (DB_HOST is set) but no password is "
            "available - check DB_PASSWORD_FILE and the mounted secret."
        )

    try:
        connection = psycopg.connect(
            host=config.DB_HOST,
            port=config.DB_PORT,
            dbname=config.DB_NAME,
            user=config.DB_USER,
            password=password,
            sslmode=config.DB_SSLMODE,
            connect_timeout=5,
            row_factory=dict_row,
        )
    except psycopg.Error as exc:
        raise DatabaseUnavailableError(
            f"Could not connect to PostgreSQL at "
            f"{config.DB_HOST}:{config.DB_PORT}/{config.DB_NAME}: {exc}"
        ) from exc

    wrapped = _PostgresConnection(connection)
    wrapped.execute(SCHEMA_POSTGRES)
    wrapped.commit()
    return wrapped


def _connect_sqlite() -> sqlite3.Connection:
    try:
        connection = sqlite3.connect(config.DB_PATH)
        connection.row_factory = sqlite3.Row
        connection.execute(SCHEMA_SQLITE)
    except sqlite3.OperationalError as exc:
        raise DatabaseUnavailableError(
            f"Could not open database at {config.DB_PATH!r}: {exc}"
        ) from exc
    return connection


def get_connection():
    """Open a connection to whichever backend is configured."""
    if config.DB_BACKEND == "postgres":
        return _connect_postgres()
    return _connect_sqlite()


def insert_note(connection, title: str, content: str) -> dict:
    """Insert a note and return the complete stored row.

    The two backends genuinely differ here - SQLite exposes `cursor.lastrowid`
    while PostgreSQL uses `RETURNING` - so this is the one operation that
    needs a backend branch rather than shared SQL.
    """
    if config.DB_BACKEND == "postgres":
        cursor = connection.execute(
            "INSERT INTO notes (title, content) VALUES (?, ?) RETURNING *",
            (title, content),
        )
        row = cursor.fetchone()
        connection.commit()
        return dict(row)

    cursor = connection.execute(
        "INSERT INTO notes (title, content) VALUES (?, ?)",
        (title, content),
    )
    connection.commit()
    row = connection.execute(
        "SELECT * FROM notes WHERE id = ?", (cursor.lastrowid,)
    ).fetchone()
    return dict(row)
