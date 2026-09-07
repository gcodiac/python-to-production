# Lesson 04 — Understanding Dependencies and Runtime

**What you'll learn:** how to read a Python project's dependency declarations, tell required dependencies apart from development-only ones, and start thinking about what a runtime environment needs to provide.

## Goal

Produce a complete, accurate list of everything this application needs to run — language version, direct dependencies, and dev/test-only dependencies — straight from the project's own configuration.

## Why this matters in real DevOps/platform work

Every dependency you can't account for is a future container build failure, a version-mismatch bug, or a security patch you don't know you need to apply. Before you package an application (in *any* form — a container, a VM image, a serverless bundle), you need to know exactly what has to be present at runtime versus what's only needed to develop or test it. Confusing the two is one of the most common mistakes juniors make when writing their first Dockerfile — bloating a production image with test tooling it will never use, or worse, missing something it needs.

## Concepts

* **Direct dependency** — a package the application imports and needs at runtime.
* **Dev/test dependency** — a package only needed while developing or testing (e.g. `pytest`, linters) — never needed for the app to actually run.
* **Version constraint** — a rule like `>=0.115` that pins acceptable versions of a dependency.
* **`requires-python`** — the interpreter version(s) the project declares it supports.

## Investigation steps

### 1. Read the dependency declarations directly

```bash
cat pyproject.toml
```

### 2. Confirm what's actually installed in your environment

```bash
source .venv/bin/activate
pip list
python3 --version
```

### 3. Inspect a couple of the direct dependencies

```bash
pip show fastapi
pip show uvicorn
```

### 4. Confirm the standard library dependency that *isn't* listed

```bash
grep -n "^import\|^from" app/database.py
```

## Questions for the learner

1. What minimum Python version does this project require? Where is that declared?
2. List every **direct runtime** dependency (the app cannot run without it) and every **dev-only** dependency (only needed to test/lint it). Which list did `ruff` and `bandit` end up in, and why does that make sense?
3. `app/database.py` uses `sqlite3` — why isn't it listed anywhere in `pyproject.toml`?
4. If you had to describe, in one sentence, what a bare-minimum environment needs to contain to run this app (ignore packaging/containers for now — just "what has to be true about the machine"), what would you say?

## Commands to run

```bash
cat pyproject.toml
python3 --version
pip list
pip show fastapi uvicorn
```

## Expected observations

The project requires Python 3.10+. Direct runtime dependencies are `fastapi` and `uvicorn[standard]`. Dev-only dependencies — `pytest`, `httpx`, `ruff`, `bandit` — live under `[project.optional-dependencies].dev` and are never imported by anything under `app/`; they exist purely to develop, test, and analyse the project. `sqlite3` isn't listed because it ships as part of the Python standard library — it needs a Python interpreter that includes it (essentially all standard CPython builds do), but it isn't a package you `pip install`.

## Practical exercise

Write a short "runtime requirements" note, as if attaching it to a ticket for whoever builds this app's eventual container image:

```text
Python version required: ...
Direct dependencies: ...
Dev-only dependencies (exclude from production install): ...
Standard-library dependencies to be aware of: ...
```

## Verification / checkpoint

Your note should clearly separate what must ship in a production runtime from what must not. If `pytest` ends up in your "direct dependencies" list, go back and re-check `pyproject.toml` — that's a real mistake that bloats real container images.

## Recap

You've extracted a precise, source-of-truth dependency and runtime picture from `pyproject.toml` rather than guessing — and separated "needed to run" from "needed to develop." That distinction will matter directly once this application is eventually packaged into a container in a later track. For now, it's time to actually run the test suite and then point some real tooling at the code.
