"""Tests for how configuration becomes a database engine.

None of these open a connection. They check the step that actually breaks
when an application moves between environments: turning configuration into
the right engine, with the right options, for the right backend.
"""

from app import config
from app.database import create_database_engine, database_backend, engine_options

SQLITE_URL = "sqlite:///./example.db"


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
