# Lesson 11 — Health Checks and Service Readiness

**What you'll learn:** why platform engineers rely on health endpoints, and a genuine gap between "the process is running" and "the application actually works" — discovered by breaking the database on purpose.

## Goal

Understand what `/health` currently checks (and doesn't), and directly observe what happens to this application when its database becomes unavailable.

## Why this matters in real DevOps/platform work

Load balancers, container orchestrators, and deployment tooling all need a fast, reliable way to answer one question: "is this instance able to serve traffic right now?" That's what a health endpoint is for. But a *shallow* health check — one that just proves the process is alive, without checking that its actual dependencies work — can be actively dangerous: it tells your platform "I'm fine" right up until every real request starts failing. Distinguishing shallow from deep health checks is exactly the kind of thing a platform engineer is expected to notice that a developer, focused on features, might not.

## Concepts

* **Liveness** — is the process running at all? (The most basic possible check.)
* **Readiness** — is the process not just running, but actually able to handle real requests right now (dependencies reachable, startup complete)?
* **Shallow vs. deep health check** — a shallow check only proves the web server itself responds; a deep check also verifies critical dependencies (like the database) are actually reachable.
* **Graceful vs. ungraceful failure** — does the application fail with a clear, informative error when something's wrong, or does it crash unpredictably / hang / return a misleading success?

## Investigation steps

### 1. Look at what `/health` actually does

```bash
grep -n -A3 "def health_check" app/main.py
```

Notice what it checks — and what it doesn't touch at all.

### 2. Start the app normally and confirm `/health` behaves as expected

```bash
source .venv/bin/activate
uvicorn app.main:app --reload &
curl -s http://127.0.0.1:8000/health
```

### 3. Now deliberately break the database and see what actually happens

Stop the app (`kill %1` or `Ctrl+C`), then start it again pointing at a database path whose directory doesn't exist:

```bash
NOTES_DB_PATH=/nonexistent-dir-xyz/notes.db uvicorn app.main:app --port 8001 &
sleep 1
curl -i http://127.0.0.1:8001/health
```

### 4. Now try an endpoint that actually touches the database

```bash
curl -i http://127.0.0.1:8001/notes
```

Watch the terminal running Uvicorn — you should see a full Python traceback printed there.

## Questions for the learner

1. Did the app fail to *start* when given a broken database path, or did it start successfully and only fail later? What does that tell you about when SQLite actually opens/creates its file?
2. What HTTP status did `GET /health` return with a completely broken database? What HTTP status did `GET /notes` return?
3. Based on what you just observed: if a load balancer or orchestrator were only checking `/health`, would it correctly detect that this instance can't actually serve real traffic? What's the practical consequence of that gap?
4. Is the traceback printed to the terminal when `/notes` fails a *log*, in the sense you covered in Lesson 10? Where does it go — `stdout` or `stderr`? (Reuse the redirection trick from Lesson 10 if you're not sure.)

## Commands to run

```bash
grep -n -A3 "def health_check" app/main.py
NOTES_DB_PATH=/nonexistent-dir-xyz/notes.db uvicorn app.main:app --port 8001 &
curl -i http://127.0.0.1:8001/health
curl -i http://127.0.0.1:8001/notes
kill %1
```

## Expected observations

The app starts up perfectly cleanly even with a broken database path — SQLite doesn't touch the filesystem until a connection is actually opened, which only happens on the first request that needs data. `GET /health` still returns `200 {"status":"ok",...}`, because it never calls `get_connection()` at all — it's a shallow check that only proves the web process itself is responding. `GET /notes`, on the other hand, returns a `500 Internal Server Error`, and the terminal shows a full traceback ending in `sqlite3.OperationalError: unable to open database file`. So: a monitoring system watching only `/health` here would report this instance as perfectly healthy, right up until every single real request to it failed. That's a real, common gap — not a contrived one.

## Practical exercise

As a **stretch exercise** (optional — don't feel you need to ship this to move on), sketch out, in plain English or pseudocode, what a *deeper* `/health` check for this app might do differently — for example, attempting `get_connection()` inside a `try`/`except` and reporting a degraded status if it fails, rather than crashing the whole request. You don't have to implement it; the point is to be able to describe the difference between what exists today and what a production-grade check would do, and why you might deliberately choose *not* to make every health check deep (hint: think about what happens if a slow database makes your liveness check itself slow or flaky).

## Verification / checkpoint

You should be able to state, from direct observation (not guesswork): the exact HTTP status codes for `/health` and `/notes` when the database is unreachable, and exactly which line in `app/database.py` is where that failure actually happens.

## Recap

You've deliberately broken a dependency and watched exactly how this application responds — discovering that "healthy" and "actually working" aren't the same claim here yet. This is precisely the kind of operational gap that's cheap to find and reason about now, and expensive to discover for the first time during a real incident. Next, you'll pull everything from this track together into one final review before this application is considered ready to containerise.
