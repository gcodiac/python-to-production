# Minimal Notes API (FastAPI)

A deliberately small Python web application designed to serve as a starting point for learning how applications evolve from local development to production.

The application is intentionally kept minimal. It contains only the core application functionality needed to run and test locally, without introducing production infrastructure, deployment automation, cloud configuration, containerization, observability, or other platform concerns.

The goal is to provide a simple application that can be forked and progressively improved while learning topics such as Platform Engineering, DevOps, Infrastructure as Code, cloud infrastructure, security, monitoring, observability, and SRE.

## Four learning tracks

This repository supports four learning paths, all grounded in this exact application, each picking up where the last one left off:

```text
Track 1
Python / FastAPI Development                  (learning/)
        ↓
Track 2
DevOps Pre-Containerisation                    (devops-learning/, devops/01-pre-containerisation)
        ↓
Track 3
Container Engineering & Supply Chain           (container-learning/, devops/02-containerisation-supply-chain)
        ↓
Track 4
CI/CD, Registry, Signing & Provenance          (cicd-learning/, devops/03-cicd)
        ↓
NEXT
Cloud Infrastructure & Deployment              (a later stage, not yet in this repository)
```

* **[learning/](learning/) — Application Development / FastAPI.** New to Python or FastAPI? This 22-lesson course builds this exact Notes API from an empty folder, from absolute basics through a finished, tested app with a working dashboard.
* **[devops-learning/](devops-learning/) — DevOps / Platform Engineering.** Already have this app (or one like it)? This 14-lesson course puts you in the position of a platform/DevOps engineer *receiving* an already-built application from a development team, and walks you through understanding, analysing, and preparing it for containerisation — investigation, static and security analysis, and environment-based configuration, all *before* a single `Dockerfile` gets written. Lives on the `devops/01-pre-containerisation` branch (and, from that branch onward).
* **[container-learning/](container-learning/) — Container Engineering & Software Supply Chain.** Takes the clean, remediated application from Track 2 and turns it into a real, inspected, tested, scanned, hardened container artefact: a production-quality multi-stage `Dockerfile`, locked dependencies, non-root runtime, persistent storage, a `compose.yaml`, dependency/image/secret scanning (`SECURITY.md`), an SBOM, and a manual release quality gate — deliberately stopping short of CI/CD. Lives on the `devops/02-containerisation-supply-chain` branch.
* **[cicd-learning/](cicd-learning/) — CI/CD, Registry, Signing & Provenance.** Automates Track 3's manual release gate with real GitHub Actions against this repository's actual GitHub remote: pull-request quality/security gates, a build-once/scan/publish-to-GHCR/SBOM/provenance/cosign-signing release workflow, and Dependabot — verified with real, observed Actions runs (including a genuine failure that was found and fixed), not just written YAML. Lives on the `devops/03-cicd` branch, with an open, unmerged Pull Request (#1) against `devops/02-containerisation-supply-chain`.

You don't have to complete one track to start the next, but each assumes familiarity with what the previous one built. Tracks 2, 3, and 4 live on their own branches specifically so their git history can teach the *process* of hardening an application/image/pipeline one deliberate step at a time - see each track's README for how to read that history.

## Why is it so minimal?

Most example applications already include many production-oriented decisions before explaining why they are needed. This project takes the opposite approach: start with a small application that works locally, then introduce production requirements only when the problems they solve become relevant.

The application therefore deliberately begins without:

* environment-based configuration
* containerization
* production databases
* deployment pipelines
* cloud infrastructure
* secret management
* production logging
* monitoring and observability
* infrastructure-specific configuration

These are not missing features. They are intentionally left for the learning journey that begins after forking this repository.

**This branch (`devops/01-pre-containerisation`) has since addressed several of them** as part of a completed pre-containerisation review: configuration (`APP_ENV`, `APP_HOST`, `APP_PORT`, `DATABASE_URL`, `LOG_LEVEL`, `APP_SECRET`) is now externalised via environment variables and `app/config.py` (see `.env.example`), and the application fails loudly rather than starting insecurely if `APP_SECRET` is missing in production. Earlier commits on this branch deliberately introduced a small set of code-quality and configuration/security problems for the [devops-learning/](devops-learning/) track to find, each originally marked with a comment containing `TRAINING-ISSUE`. If you want to work through that investigation yourself rather than see the finished result, check out an earlier commit on this branch (before the "Fix static analysis findings" commit) and run `grep -rn "TRAINING-ISSUE" app/` there — the lessons in [devops-learning/](devops-learning/) still describe that exercise in full. The current tip of this branch is the worked example of what completing it looks like.

## What this application contains

* a small FastAPI application (`app/main.py`)
* a simple Notes API (create, read, update, delete) plus `/health` and `/ready` endpoints
* a glassmorphic dashboard UI (`app/static/`) served at `/`, built with plain HTML/CSS/JS against the API — no frontend framework or build step
* a database-agnostic storage layer built on SQLAlchemy (`app/database.py`) — runs on SQLite *or* PostgreSQL, chosen by configuration
* environment-based configuration (`app/config.py`, `.env.example`)
* basic automated tests (`tests/test_notes.py`)
* Python project configuration (`pyproject.toml`) and locked dependencies (`requirements.txt`, `requirements-dev.txt`)
* a production-quality container image (`Dockerfile`, `.dockerignore`, `compose.yaml`) and its security scanning results (`SECURITY.md`) — see the [container-learning/](container-learning/) track
* real GitHub Actions CI/CD (`.github/workflows/`) and dependency-update automation (`.github/dependabot.yml`) — see the [cicd-learning/](cicd-learning/) track

## Running locally

```bash
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"

cp .env.example .env   # first time only - adjust values as needed

uvicorn app.main:app --reload
```

The dashboard is now available at `http://127.0.0.1:8000`. Interactive API docs are available at `http://127.0.0.1:8000/docs`.

Configuration is read from environment variables (see `.env.example` for the full list) with safe local-development defaults, except `APP_SECRET`, which the app refuses to start without whenever `APP_ENV=production`.

### Choosing a database

The application talks to its database through SQLAlchemy, so one environment variable selects the backend — no code change, no separate build:

```bash
# SQLite (the default): a single file, nothing to install or start
DATABASE_URL=sqlite:///./notes.db

# PostgreSQL: requires a PostgreSQL server reachable at that address
DATABASE_URL=postgresql+psycopg://notes:your-password@localhost:5432/notes
```

SQLite is the default on purpose. It needs no server, starts instantly, and keeps the test suite fast — it is the right tool for local development on an application this size. PostgreSQL exists as an equally supported option for anyone who wants to develop against the same kind of database a production deployment would use. Neither is the "correct" choice; the point is that the application does not care, and switching costs one line of configuration.

`/ready` reports which backend it actually reached:

```bash
curl -s http://127.0.0.1:8000/ready
# {"status":"ready","database":"sqlite"}
```

Where the password must not sit in a URL — a deployment reading it from a mounted secret, for example — the connection details can instead be supplied as `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` plus `DB_PASSWORD_FILE`. `DATABASE_URL` always takes precedence when both are present; see `.env.example` for the full precedence rules.

## Running the tests

```bash
pytest
```

The tests run against a throwaway SQLite database, so no PostgreSQL server is needed to run them. The PostgreSQL configuration is covered by tests that build engines without connecting to anything (`tests/test_database_config.py`).

## Running in a container

On the `devops/02-containerisation-supply-chain` branch, the same application also runs as a container — see [container-learning/](container-learning/) for how the `Dockerfile` and the two Compose files got there, one deliberate step at a time.

```bash
cp .env.example .env   # first time only
```

There are **two** local modes. Both build and run the *same* image from the *same* `Dockerfile`; only the runtime topology differs.

### Option 1 — SQLite (simple, the default)

```bash
docker compose up --build
```

| | |
|---|---|
| Database | SQLite, a single file inside the container |
| Volume | `notes-data` (mounted at `/data`) |
| Extra services | none |
| Stop | `docker compose down` |
| Delete its data | `docker compose down -v` |

Nothing to install, nothing else to start. This is the right choice for most local work.

### Option 2 — PostgreSQL (production-shaped)

```bash
docker compose -f compose.postgres.yaml up --build
```

| | |
|---|---|
| Database | PostgreSQL 17.6, in its own container |
| Volume | `postgres-data` (PostgreSQL's data directory) |
| Extra services | `postgres`, reached at the hostname `postgres` over the Compose network |
| Stop | `docker compose -f compose.postgres.yaml down` |
| Delete its data | `docker compose -f compose.postgres.yaml down -v` |

Use this when you want the same database engine the cloud deployment uses — to reproduce a backend-specific bug, or to see how the application behaves when its database is a separate service that can fail independently.

Either way, ask the application which backend it actually reached:

```bash
curl -s http://127.0.0.1:8000/ready
# {"status":"ready","database":"sqlite"}      <- Option 1
# {"status":"ready","database":"postgresql"}  <- Option 2
```

> **The two modes have separate data.** `notes-data` and `postgres-data` are independent volumes; a note created in one mode will not appear in the other. Switching backends is not a data migration. Adding `-v` to `down` **permanently deletes** that mode's volume.

Both modes publish port 8000 on the host, so stop one before starting the other.

The manual release quality gate (tests, linting, security scanning, image scanning, SBOM generation, plus SQLite *and* PostgreSQL smoke tests against the built image) is documented in `SECURITY.md` and wrapped in `Makefile` (`make check`) once you're comfortable with the individual commands it runs.

## API

| Method | Path          | Description        |
|--------|---------------|---------------------|
| GET    | `/notes`      | List all notes      |
| POST   | `/notes`      | Create a note        |
| GET    | `/notes/{id}` | Get a single note    |
| PUT    | `/notes/{id}` | Update a note         |
| DELETE | `/notes/{id}` | Delete a note         |
| GET    | `/health`     | Basic liveness/readiness check |

A note has the shape:

```json
{
  "id": 1,
  "title": "Groceries",
  "content": "Milk, eggs",
  "created_at": "2026-08-25 12:00:00"
}
```

## Intended use

This repository acts as a reusable starting application. A learner can fork it and take the application through a complete journey from:

```text
Local application
        ↓
Understanding & analysing an inherited app   (devops-learning/, devops/01-pre-containerisation)
        ↓
Application configuration                     (devops-learning/ - complete on that branch)
        ↓
Containerization                                 (container-learning/, devops/02-containerisation-supply-chain)
        ↓
Container security, SBOMs, manual release gate     (container-learning/ - complete on that branch)
        ↓
CI/CD, registry, signing, provenance                 (cicd-learning/, devops/03-cicd - complete on that branch)   <- you are here
        ↓
Infrastructure as Code
        ↓
Cloud infrastructure
        ↓
Production databases
        ↓
Networking and security
        ↓
Monitoring and observability
        ↓
Reliability and production operations
```

The application should remain simple enough that the focus stays on understanding the engineering required around the application rather than on application business logic.
