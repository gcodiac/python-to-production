"""Tests for how configuration becomes a database engine.

None of these open a connection. They check the step that actually breaks
when an application moves between environments: turning configuration into
the right engine, with the right options, for the right backend.
"""

import pytest

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

# --- Configuration precedence ----------------------------------------------
#
# The application accepts either a complete DATABASE_URL or the individual
# DB_* components. These tests pin down which one wins, because "which
# setting was actually in effect?" is one of the most expensive questions to
# answer during an incident.


@pytest.fixture
def db_env(monkeypatch):
    """Clear every database variable, then let a test set the ones it cares about."""
    for name in (
        "DATABASE_URL",
        "DB_HOST",
        "DB_PORT",
        "DB_NAME",
        "DB_USER",
        "DB_SSLMODE",
        "DB_PASSWORD",
        "DB_PASSWORD_FILE",
    ):
        monkeypatch.setattr(config, name, None, raising=False)
    monkeypatch.setattr(config, "DB_PORT", 5432)
    monkeypatch.setattr(config, "DB_NAME", "notes")
    monkeypatch.setattr(config, "DB_USER", "notes")
    return monkeypatch


def test_no_configuration_falls_back_to_sqlite(db_env):
    assert config.database_url() == config.DEFAULT_DATABASE_URL


def test_database_url_is_used_verbatim(db_env):
    db_env.setattr(config, "DATABASE_URL", SQLITE_URL)
    assert config.database_url() == SQLITE_URL


def test_database_url_wins_over_components(db_env):
    """An explicit URL is never quietly overridden by leftover DB_* variables."""
    db_env.setattr(config, "DATABASE_URL", SQLITE_URL)
    db_env.setattr(config, "DB_HOST", "db.example.internal")
    db_env.setattr(config, "DB_PASSWORD", "unused")
    assert config.database_url() == SQLITE_URL


def test_components_build_a_postgres_url(db_env):
    db_env.setattr(config, "DB_HOST", "db.example.internal")
    db_env.setattr(config, "DB_PASSWORD", "s3cret")

    url = config.database_url()
    assert url.get_backend_name() == "postgresql"
    assert url.host == "db.example.internal"
    assert url.port == 5432
    assert url.database == "notes"
    assert url.password == "s3cret"


def test_reserved_characters_in_the_password_survive(db_env):
    """The exact bug hand-built URL strings introduce: '@' splits the host off."""
    db_env.setattr(config, "DB_HOST", "db.example.internal")
    db_env.setattr(config, "DB_PASSWORD", "p@ss:w/rd?")

    url = config.database_url()
    assert url.password == "p@ss:w/rd?"
    assert url.host == "db.example.internal"


def test_password_file_is_preferred_over_the_variable(db_env, tmp_path):
    secret = tmp_path / "db_password"
    secret.write_text("from-the-file\n", encoding="utf-8")

    db_env.setattr(config, "DB_HOST", "db.example.internal")
    db_env.setattr(config, "DB_PASSWORD", "from-the-variable")
    db_env.setattr(config, "DB_PASSWORD_FILE", str(secret))

    assert config.read_db_password() == "from-the-file"
    assert config.database_url().password == "from-the-file"


def test_sslmode_is_only_added_when_asked_for(db_env):
    db_env.setattr(config, "DB_HOST", "db.example.internal")
    db_env.setattr(config, "DB_PASSWORD", "s3cret")
    assert "sslmode" not in config.database_url().query

    db_env.setattr(config, "DB_SSLMODE", "require")
    assert config.database_url().query["sslmode"] == "require"


def test_missing_password_fails_loudly(db_env):
    """Half-configured is worse than unconfigured, so it must not be tolerated."""
    db_env.setattr(config, "DB_HOST", "db.example.internal")

    with pytest.raises(config.ConfigurationError) as excinfo:
        config.database_url()
    assert "DB_PASSWORD_FILE" in str(excinfo.value)
