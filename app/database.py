"""Storage layer.

The application reaches its database through SQLAlchemy Core rather than a
driver-specific API, which is what makes the same Python code run unchanged
against more than one database:

    Application
        |
        v
    SQLAlchemy
        |
        +---- SQLite       (a file on disk - the local default)
        |
        +---- PostgreSQL   (a client/server database, via psycopg)

Nothing in this module decides *which* database is used. That decision comes
entirely from configuration (`DATABASE_URL`, see app/config.py), so pointing
the application somewhere new is a configuration change, never a code change.

See devops-learning/12-designing-for-database-portability.md.
"""

from datetime import datetime, timezone

from sqlalchemy import Column, Integer, MetaData, Table, Text, create_engine
from sqlalchemy.engine import Connection, Engine, make_url
from sqlalchemy.exc import SQLAlchemyError

from app import config

metadata = MetaData()


def _utc_timestamp() -> str:
    """Return the current UTC time in the format the API exposes.

    Deliberately generated in Python rather than by the database. A
    server-side default has to be written in each database's own dialect
    (`datetime('now')` for SQLite, `now()` for PostgreSQL), which is exactly
    the kind of per-backend divergence this application is trying to avoid.
    One Python default is identical everywhere.
    """
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


# The table definition, expressed once, in terms SQLAlchemy can render as
# valid DDL for whichever backend is configured. `metadata.create_all()`
# below issues the correct CREATE TABLE for that backend - there is no
# hand-written, per-database schema SQL anywhere in this application.
notes = Table(
    "notes",
    metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("title", Text, nullable=False),
    Column("content", Text, nullable=False, default=""),
    Column("created_at", Text, nullable=False, default=_utc_timestamp),
)


class DatabaseUnavailableError(RuntimeError):
    """Raised when the configured database cannot be reached.

    Translating the low-level SQLAlchemy/driver error here keeps callers
    (app/main.py) from needing to know which backend is in use, or that
    SQLAlchemy is involved at all.
    """


def describe_url(url) -> str:
    """Render a database URL safely enough to appear in a log or an error.

    `render_as_string()` masks the password by default. Never format a
    database URL with an f-string for logging: that is how credentials end up
    in log aggregators.
    """
    return make_url(url).render_as_string(hide_password=True)


def database_backend(url=None) -> str:
    """Return the configured backend name, e.g. "sqlite".

    Useful for reporting (the readiness endpoint says which backend it just
    talked to), not for branching application behaviour.
    """
    return make_url(url or config.database_url()).get_backend_name()


def engine_options(url) -> dict:
    """Return the SQLAlchemy engine options appropriate for one database URL.

    This function is the *only* place in the application that looks at which
    backend is in use, and it does so for one narrow reason: some engine
    options are meaningful for one database and invalid for another. That is
    a genuine backend difference, not application logic.
    """
    url = make_url(url)

    options: dict = {
        # Verify a pooled connection is still alive before handing it out.
        # Harmless for a local file; important for any networked database,
        # where idle connections get closed by the server or a firewall.
        "pool_pre_ping": True,
    }

    if url.get_backend_name() == "sqlite":
        # SQLite refuses, by default, to use a connection from a thread other
        # than the one that opened it. FastAPI runs synchronous endpoints in a
        # worker thread pool, so that guard has to be relaxed here.
        #
        # This option exists *only* on SQLite. Handing it to another driver is
        # an error, which is precisely why it must not be applied blindly to
        # every engine.
        options["connect_args"] = {"check_same_thread": False}

    return options


def create_database_engine(url=None) -> Engine:
    """Build a SQLAlchemy engine for the given (or configured) database URL."""
    url = make_url(url or config.database_url())
    return create_engine(url, **engine_options(url))


# One engine per process, created on first use. An engine owns a connection
# pool, so building a fresh one per request would throw away pooling entirely.
_engine: Engine | None = None


def get_engine() -> Engine:
    """Return the process-wide engine, creating the schema on first use."""
    global _engine

    if _engine is None:
        engine = create_database_engine()
        try:
            metadata.create_all(engine)
        except SQLAlchemyError as exc:
            engine.dispose()
            raise DatabaseUnavailableError(
                f"Could not reach the database at {describe_url(engine.url)}: {exc}"
            ) from exc
        _engine = engine

    return _engine


def get_connection() -> Connection:
    """Check out a connection from the pool."""
    try:
        return get_engine().connect()
    except SQLAlchemyError as exc:
        raise DatabaseUnavailableError(f"Could not connect to the database: {exc}") from exc


def insert_note(connection: Connection, title: str, content: str) -> dict:
    """Insert a note and return the complete stored row.

    Reading the row back by its generated primary key works on every backend
    SQLAlchemy supports. Databases differ in how they hand back a generated
    key - `lastrowid`, `RETURNING`, a sequence - and `inserted_primary_key`
    is SQLAlchemy's single answer to all of them.
    """
    result = connection.execute(notes.insert().values(title=title, content=content))
    connection.commit()

    note_id = result.inserted_primary_key[0]
    row = connection.execute(notes.select().where(notes.c.id == note_id)).one()
    return dict(row._mapping)
