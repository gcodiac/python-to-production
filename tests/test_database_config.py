"""Tests for how configuration becomes a database engine.

None of these open a connection. They check the step that actually breaks
when an application moves between environments: turning configuration into
the right engine, with the right options, for the right backend.
"""

from app import config
from app.database import (
    create_database_engine,
    database_backend,
    describe_url,
    engine_options,
)

SQLITE_URL = "sqlite:///./example.db"

# A syntactically valid PostgreSQL URL pointing at nothing. These tests never
# connect, so no PostgreSQL server is needed to run the Stage 1 test suite.
POSTGRES_URL = "postgresql+psycopg://notes:not-a-real-password@localhost:5432/notes"


def test_default_url_is_local_sqlite():
    """A developer with no configuration at all still gets a working app."""
    assert config.DEFAULT_DATABASE_URL.startswith("sqlite:")


def test_sqlite_url_selects_the_sqlite_backend():
    engine = create_database_engine(SQLITE_URL)
    assert engine.dialect.name == "sqlite"
    assert database_backend(SQLITE_URL) == "sqlite"


def test_sqlite_engine_relaxes_the_same_thread_check():
    """FastAPI serves sync endpoints from a thread pool, so SQLite needs this."""
    assert engine_options(SQLITE_URL)["connect_args"] == {"check_same_thread": False}


def test_postgres_url_selects_the_postgres_backend():
    """Proves the driver is installed: create_engine() imports it eagerly."""
    engine = create_database_engine(POSTGRES_URL)
    assert engine.dialect.name == "postgresql"
    assert engine.dialect.driver == "psycopg"
    assert database_backend(POSTGRES_URL) == "postgresql"


def test_postgres_engine_does_not_get_sqlite_options():
    """check_same_thread is a SQLite argument; psycopg would reject it."""
    assert "connect_args" not in engine_options(POSTGRES_URL)


def test_pool_pre_ping_applies_to_every_backend():
    assert engine_options(SQLITE_URL)["pool_pre_ping"] is True
    assert engine_options(POSTGRES_URL)["pool_pre_ping"] is True


def test_describe_url_never_reveals_the_password():
    described = describe_url(POSTGRES_URL)
    assert "not-a-real-password" not in described
    assert "localhost:5432/notes" in described
