# Lesson 01 — Understanding the Application

**What you'll learn:** how to use `tree`, `find`, and `grep`/`rg` to build a factual picture of what a codebase does, without reading every file top to bottom.

## Goal

Turn your Lesson 00 hypotheses into confirmed facts: what this application does, what its major pieces are, and how a user actually interacts with it — all *before* you try to run it.

## Why this matters in real DevOps/platform work

You will rarely have time to read an inherited application file-by-file. Platform engineers learn to sweep a codebase quickly using a handful of tools — directory structure, targeted `grep`, and skimming key files — to build an accurate mental model fast. This is a skill, and it's the same skill whether the codebase is 5 files or 5,000.

## Concepts

* **Surface area** — everything a user or another system can directly interact with (in a web app: its HTTP endpoints and served files).
* **Entry point** — the file/object that a runtime actually starts from (for a FastAPI app, the `FastAPI()` instance).
* **Skimming vs. reading** — briefly scanning many files to find what's relevant, versus closely reading the few files that matter.

## Investigation steps

### 1. See the whole shape of the project

```bash
tree -I '__pycache__|*.egg-info' .
```

If `tree` isn't installed, `find . -not -path '*/__pycache__*' | sort` gives you the same information in a flatter form.

### 2. Find every Python source file

```bash
find app -name "*.py"
```

### 3. Find the application's entry point

FastAPI apps are built around a `FastAPI()` object. Search for it:

```bash
grep -rn "FastAPI(" app/
```

### 4. Find every route the API exposes

```bash
grep -rn "@app\." app/main.py
```

(`rg "@app\." app/main.py` works the same way if you have ripgrep installed, and is faster on larger codebases.)

### 5. Look at the static frontend

```bash
ls app/static/
head -30 app/static/index.html
```

## Questions for the learner

1. How many HTTP routes does the API expose, and what HTTP method/path is each one?
2. What does a single "note" look like as JSON? (Hint: check `app/models.py`.)
3. Is the browser dashboard (`app/static/`) served by a separate web server, or by the same FastAPI process? Look for `StaticFiles` in `app/main.py`.
4. What does the `/health` route return? What might that be for? (You'll cover this properly in Lesson 11 — just note it for now.)

## Commands to run

```bash
cat app/models.py
grep -n "app.mount\|StaticFiles" app/main.py
grep -n "@app.get\|@app.post\|@app.put\|@app.delete" app/main.py
```

## Expected observations

You should find five CRUD-style routes under `/notes` (`GET /notes`, `POST /notes`, `GET /notes/{note_id}`, `PUT /notes/{note_id}`, `DELETE /notes/{note_id}`), plus a `/health` route. You should find that `app.mount("/", StaticFiles(...))` serves the dashboard from the *same* FastAPI process — there is no separate frontend server. A note has `id`, `title`, `content`, and `created_at`.

## Practical exercise

Write a short paragraph (3–5 sentences) describing this application as if explaining it to a new teammate who has never seen it, covering: what it does, what technology it's built with, and how the frontend and backend relate to each other. Also list all six routes you found with their HTTP methods.

## Verification / checkpoint

Compare your route list against the table in the project [README.md](../README.md#api). If you're missing `/health`, that's expected at this stage — it isn't in the README yet because it was added after the README was last written. That mismatch is itself a realistic observation: documentation drifts out of date, and you can't always trust it fully.

## Recap

You now have a confirmed, evidence-based description of what the application does and what its surface area looks like — built entirely from directory structure and targeted searches rather than reading every line. Next, you'll turn this into an actual architecture diagram.
