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
from sqlalchemy.engine import URL

load_dotenv()

APP_ENV = os.environ.get("APP_ENV", "development")

# Binding to 127.0.0.1 by default means the app is only reachable from the
# same machine unless something deliberately opts in to more (e.g. a
# container runtime setting APP_HOST=0.0.0.0 explicitly).
APP_HOST = os.environ.get("APP_HOST", "127.0.0.1")
APP_PORT = int(os.environ.get("APP_PORT", "8000"))

LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")

# --- Database configuration ------------------------------------------------
#
# DATABASE_URL is the single canonical way to tell this application where its
# data lives. It is a SQLAlchemy URL, so one variable selects both the
# database engine and its location:
#
#   sqlite:///./notes.db                                a local file
#   postgresql+psycopg://user:password@host:5432/notes  a database server
#
# The earlier NOTES_DB_PATH variable is gone on purpose. Two ways to say the
# same thing is one too many: it doubles the number of states a reviewer has
# to reason about and hides which one actually won.
#
# There is, however, one situation a single URL handles badly: when the
# password must not be written down next to everything else. A password
# embedded in DATABASE_URL has to be assembled by whatever sets that variable,
# which usually means the password ends up in a deployment manifest, a shell
# history, or a process listing. So the application also accepts the
# connection details as separate components, with the password delivered on
# its own - ideally as a file the runtime mounts.
#
# Precedence, in order:
#
#   1. DATABASE_URL             used exactly as given
#   2. DB_HOST (+ DB_*)         a PostgreSQL URL is assembled from the parts
#   3. neither                  DEFAULT_DATABASE_URL - local SQLite
DEFAULT_DATABASE_URL = "sqlite:///./notes.db"

DATABASE_URL = os.environ.get("DATABASE_URL")

DB_HOST = os.environ.get("DB_HOST")
DB_PORT = int(os.environ.get("DB_PORT", "5432"))
DB_NAME = os.environ.get("DB_NAME", "notes")
DB_USER = os.environ.get("DB_USER", "notes")

# Left unset by default so the driver's own default applies. A deployment
# talking to a database over an untrusted network should set this to
# "require" (or stricter) - that is a property of the environment, not of
# the application, so the application does not presume it.
DB_SSLMODE = os.environ.get("DB_SSLMODE")

# Two ways to supply the password, deliberately ordered:
#
#   DB_PASSWORD_FILE   a path the runtime mounts a secret into. Preferred:
#                      file contents do not appear in `env`, in a process
#                      listing, in `docker inspect`, or in a crash report.
#   DB_PASSWORD        the plain environment variable. Convenient for a
#                      throwaway local database; weaker everywhere else.
DB_PASSWORD_FILE = os.environ.get("DB_PASSWORD_FILE")
DB_PASSWORD = os.environ.get("DB_PASSWORD")

# The SQLAlchemy dialect+driver used when the URL is assembled from parts.
POSTGRES_DRIVER = "postgresql+psycopg"


class ConfigurationError(RuntimeError):
    """Raised when the supplied configuration cannot produce a usable database.

    Failing loudly at this point is deliberate. A half-configured database is
    the kind of problem that otherwise surfaces as a confusing error on the
    first request that happens to touch storage.
    """


def read_db_password() -> str | None:
    """Return the database password, preferring the file over the variable.

    Read on each call rather than cached at import time, so a rotated secret
    is picked up without restarting the process.
    """
    if DB_PASSWORD_FILE:
        try:
            with open(DB_PASSWORD_FILE, encoding="utf-8") as handle:
                return handle.read().strip()
        except OSError:
            return None
    return DB_PASSWORD


def database_url() -> str | URL:
    """Return the SQLAlchemy URL the application should connect to."""
    if DATABASE_URL:
        return DATABASE_URL

    if DB_HOST:
        password = read_db_password()
        if not password:
            raise ConfigurationError(
                "DB_HOST is set but no password is available - set "
                "DB_PASSWORD_FILE (preferred) or DB_PASSWORD."
            )
        # URL.create() escapes each component correctly. Building this string
        # by hand is a real bug, not a style preference: a password containing
        # "@", ":" or "/" silently produces a URL pointing at the wrong host.
        return URL.create(
            POSTGRES_DRIVER,
            username=DB_USER,
            password=password,
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            query={"sslmode": DB_SSLMODE} if DB_SSLMODE else {},
        )

    return DEFAULT_DATABASE_URL


# Unlike the values above, APP_SECRET does not get a real fallback: a secret
# that silently defaults to a known placeholder in production is worse than
# no secret at all. Outside production, a placeholder is fine so the app can
# still be started with zero configuration.
APP_SECRET = os.environ.get("APP_SECRET")
if not APP_SECRET:
    if APP_ENV == "production":
        raise RuntimeError(
            "APP_SECRET must be set via an environment variable when "
            "APP_ENV=production - refusing to start with no secret configured."
        )
    # A static analysis / security scan will still flag this line (a string
    # literal assigned to a secret-shaped name) - that's a reviewed, accepted
    # finding rather than a bug: the guard above guarantees this branch is
    # unreachable whenever APP_ENV=production, so this value is never used
    # outside local development.
    APP_SECRET = "dev-only-secret-not-for-production"
