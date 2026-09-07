# Minimal Notes API (FastAPI)

A deliberately small Python web application designed to serve as a starting point for learning how applications evolve from local development to production.

The application is intentionally kept minimal. It contains only the core application functionality needed to run and test locally, without introducing production infrastructure, deployment automation, cloud configuration, containerization, observability, or other platform concerns.

The goal is to provide a simple application that can be forked and progressively improved while learning topics such as Platform Engineering, DevOps, Infrastructure as Code, cloud infrastructure, security, monitoring, observability, and SRE.

## Learn how this was built

New to Python or FastAPI? Follow the step-by-step [learning/](learning/) course — 22 lessons from absolute basics to a finished, tested app.

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

## What this application contains

* a small FastAPI application (`app/main.py`)
* a simple Notes API (create, read, update, delete)
* a glassmorphic dashboard UI (`app/static/`) served at `/`, built with plain HTML/CSS/JS against the API — no frontend framework or build step
* SQLite for local persistence (`app/database.py`)
* basic automated tests (`tests/test_notes.py`)
* Python project configuration (`pyproject.toml`)

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
Application configuration
        ↓
Containerization
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
