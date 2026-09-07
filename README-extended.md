# Notes API — extended reference

> The long-form version of [README.md](README.md), kept for depth: full rationale, the complete track descriptions, and the reasoning behind each decision on this branch. Start with the short README if you just want to run the thing.

A deliberately small Python web application designed to serve as a starting point for learning how applications evolve from local development to production.

The application is intentionally kept minimal. It contains only the core application functionality needed to run and test locally, without introducing production infrastructure, deployment automation, cloud configuration, containerization, observability, or other platform concerns.

The goal is to provide a simple application that can be forked and progressively improved while learning topics such as Platform Engineering, DevOps, Infrastructure as Code, cloud infrastructure, security, monitoring, observability, and SRE.

## Two learning tracks

This repository supports two different learning paths, both grounded in this exact application.

* **[learning/](learning/) — Application Development / FastAPI.** New to Python or FastAPI? This 22-lesson course builds this exact Notes API from an empty folder, from absolute basics through a finished, tested app with a working dashboard.
* **[devops-learning/](devops-learning/) — DevOps / Platform Engineering.** Already have this app (or one like it)? This 14-lesson course puts you in the position of a platform/DevOps engineer *receiving* an already-built application from a development team, and walks you through understanding, analysing, and preparing it for containerisation — investigation, static and security analysis, and environment-based configuration, all *before* a single `Dockerfile` gets written.

You don't have to complete the first track to start the second, but it helps to at least skim [learning/](learning/) so the application itself isn't unfamiliar.

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

For the same reason, the application code also contains a small number of **deliberate** code-quality and configuration/security problems for the [devops-learning/](devops-learning/) track to find — hard-coded configuration, a fake placeholder secret, and a handful of realistic maintainability issues. Every one of them is marked in the source with a comment containing `TRAINING-ISSUE`, so you can always find the full list with `grep -rn "TRAINING-ISSUE" app/`. If you're working through [learning/](learning/) instead, you can ignore these entirely — they don't affect how the application runs.

## What this application contains

* a small FastAPI application (`app/main.py`)
* a simple Notes API (create, read, update, delete) plus a `/health` endpoint
* a glassmorphic dashboard UI (`app/static/`) served at `/`, built with plain HTML/CSS/JS against the API — no frontend framework or build step
* SQLite for local persistence (`app/database.py`)
* basic automated tests (`tests/test_notes.py`)
* Python project configuration (`pyproject.toml`), including optional `ruff`/`bandit` dev tooling used by the DevOps track

## Running locally

```bash
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"

uvicorn app.main:app --reload
```

The dashboard is now available at `http://127.0.0.1:8000`. Interactive API docs are available at `http://127.0.0.1:8000/docs`.

## Running the tests

```bash
pytest
```

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
Understanding & analysing an inherited app   <- devops-learning/ covers this far
        ↓
Application configuration                       (devops-learning/)
        ↓
Containerization                                 (a later track — not yet in this repo)
        ↓
CI/CD
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
