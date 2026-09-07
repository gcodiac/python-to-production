# Lesson 02 — Mapping the Architecture

**What you'll learn:** how to trace a request from the browser all the way down to storage, and express that as a simple architecture diagram.

## Goal

Produce your own text or hand-drawn diagram of how a request flows through this application, confirmed by reading the actual code — not guessed from the README.

## Why this matters in real DevOps/platform work

Before you can containerise, scale, monitor, or secure a system, you need to know what actually talks to what. Real production incidents are frequently traced back to someone's mental model of the architecture being wrong — assuming a cache exists when it doesn't, or that a service is stateless when it secretly writes to a local disk. Building an accurate architecture diagram from the source, not from documentation, is a core platform-engineering habit.

## Concepts

* **Client** — whatever originates a request (here: a web browser).
* **Application server** — the process that receives requests and decides what to do with them (here: the FastAPI/Uvicorn process).
* **Persistence layer** — where data outlives a single request (here: a database file on disk).
* **Static assets** — files served as-is (HTML/CSS/JS) rather than generated per-request.

## Investigation steps

### 1. Confirm how the database connection is created

```bash
cat app/database.py
```

Answer for yourself: what Python library is used to talk to the database? What database *technology* is that (not just the library name)? Where — what path, relative to what — will the actual database file be created?

### 2. Confirm what talks to the database

```bash
grep -n "get_connection" app/main.py
```

Every route that touches data calls this one function. That's your persistence boundary.

### 3. Confirm what's stateless vs. stateful

Which of these hold state between requests: the FastAPI process itself, the SQLite file, the browser? (There's no cache, session store, or message queue here — this app is intentionally simple. Don't go looking for infrastructure that isn't there.)

### 4. Confirm the request path for the dashboard vs. the API

Open `app/static/app.js` and find the constant at the top of the file:

```bash
head -5 app/static/app.js
```

What URL does the browser's JavaScript call to load notes? Is that a different process/port from the one serving `index.html`, or the same one?

## Questions for the learner

1. In your own words: what database technology does this app use, and where does the database file live by default?
2. Does the browser talk directly to the database at any point? Why or why not?
3. If this process stopped and restarted, would the notes still be there? What does that tell you about where "state" actually lives in this system?

## Commands to run

```bash
cat app/database.py
grep -n "get_connection" app/main.py
head -5 app/static/app.js
```

## Expected observations

The app uses Python's built-in `sqlite3` module, meaning the database technology is **SQLite** — a single-file, serverless database. The file path comes from an environment variable `NOTES_DB_PATH`, falling back to `notes.db` in the current working directory if that variable isn't set. The browser never talks to SQLite directly — it only ever calls the FastAPI process over HTTP (both for the API and for the dashboard's HTML/CSS/JS), and the FastAPI process is the only thing that opens the database file.

That is the architecture *as inherited*. By the end of this track the storage layer is no longer wired to one specific database — see [Lesson 12](12-designing-for-database-portability.md), where the same application becomes able to run on either SQLite or PostgreSQL through configuration alone.

## Practical exercise

Draw (in text, ASCII, or on paper) your own version of this diagram, labelling each arrow with what actually flows across it (HTTP requests, JSON, SQL, or file reads):

```text
Browser
   |
   v
FastAPI application
   |
   +---- REST API (/notes, /health)
   |
   +---- Static HTML/CSS/JavaScript (/)
   |
   v
SQLite database file
```

Add one thing this diagram is *missing* that a production version of this architecture would probably need (you don't need to build it — just name it, e.g. "a way to run more than one copy of this process").

## Verification / checkpoint

You should be able to point at the exact line in `app/database.py` that decides the database file's location, and the exact line in `app/main.py` that mounts the static dashboard. If you had to guess at either, go back and find them for real — don't move on with an unconfirmed diagram.

## Recap

You've traced the full request path — browser → FastAPI → SQLite — directly from source code, and produced your own architecture diagram grounded in evidence rather than assumption. Next, you'll actually get this application running.
