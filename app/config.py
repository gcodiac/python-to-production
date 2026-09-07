"""Application configuration.

Every value here is read from the environment, with sensible defaults for
local development only. This is the single place the rest of the app should
get configuration from - nothing else should read `os.environ` directly.

For local development, copy `.env.example` to `.env` and adjust as needed;
`load_dotenv()` below loads that file into the environment automatically.
Environment variables that are already set (e.g. by a container runtime or
CI) always take priority over anything in `.env`.
"""

import os

from dotenv import load_dotenv

load_dotenv()

APP_ENV = os.environ.get("APP_ENV", "development")

# Binding to 127.0.0.1 by default means the app is only reachable from the
# same machine unless something deliberately opts in to more (e.g. a
# container runtime setting APP_HOST=0.0.0.0 explicitly).
APP_HOST = os.environ.get("APP_HOST", "127.0.0.1")
APP_PORT = int(os.environ.get("APP_PORT", "8000"))

LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")

# DATABASE_URL is the canonical way to configure storage location. NOTES_DB_PATH
# is still honoured for backwards compatibility with earlier configuration.
DATABASE_URL = (
    os.environ.get("DATABASE_URL")
    or os.environ.get("NOTES_DB_PATH")
    or "sqlite:///./notes.db"
)


def _sqlite_path(database_url: str) -> str:
    """Turn a sqlite:/// URL into a plain filesystem path sqlite3.connect() accepts.

    A bare path (no "sqlite:///" prefix) is returned unchanged, so existing
    NOTES_DB_PATH-style values keep working exactly as before.
    """
    return database_url.removeprefix("sqlite:///")


DB_PATH = _sqlite_path(DATABASE_URL)

APP_SECRET = os.environ.get("APP_SECRET", "dev-only-secret-not-for-production")
