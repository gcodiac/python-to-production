# Lesson 08 — Environment Variables and dotenv

**What you'll learn:** how environment variables work, how Python reads them, how `.env` files and `python-dotenv` fit in — and then you'll actually externalise the configuration you inventoried in Lesson 07 yourself.

## Goal

By the end of this lesson, every value in your Lesson 07 inventory table should be read from an environment variable, with a working `.env` file (git-ignored) supplying local development values, and a committed `.env.example` documenting what's required.

**This lesson does not do the refactor for you.** It teaches you the pattern and points you at exactly what to change; writing the code is your exercise.

## Why this matters in real DevOps/platform work

This is the mechanism behind almost every modern deployment platform's configuration story — Docker's `--env-file`, Kubernetes `ConfigMap`s and `Secret`s, cloud platform "environment variables" settings panels. If you understand this pattern deeply now, every one of those later tools will feel like a thin wrapper around something you already know, rather than new magic to memorise.

## Concepts

* **Environment variable** — a key/value pair available to a process from its operating system environment, set before the process starts.
* **`os.environ.get(name, default)`** — Python's standard way to read one, with a fallback if it isn't set. You already have a working example of this pattern in `app/database.py`.
* **`.env` file** — a plain-text file of `KEY=value` lines, used to supply environment variables during *local development* (never committed — it often contains real local secrets).
* **`python-dotenv`** — a small library that loads a `.env` file's contents into `os.environ` automatically, so you don't have to `export` everything by hand every time you open a terminal.
* **`.env.example`** — a *committed* file listing every variable the app needs, with placeholder or non-secret example values, so a new developer knows what to create locally.

## The pattern, demonstrated in isolation

Here's the exact mechanism, outside of this app's code, so you can see it clearly before applying it:

```python
import os

# Reads the LOG_LEVEL environment variable if set, otherwise falls back to "INFO"
log_level = os.environ.get("LOG_LEVEL", "INFO")
```

Try it at a Python prompt:

```bash
source .venv/bin/activate
python3 -c 'import os; print(os.environ.get("LOG_LEVEL", "INFO"))'
LOG_LEVEL=DEBUG python3 -c 'import os; print(os.environ.get("LOG_LEVEL", "INFO"))'
```

You should see `INFO` the first time and `DEBUG` the second — the same one-line Python code, two different results, controlled entirely from outside the code. That's the whole point.

`app/database.py` already does exactly this for `NOTES_DB_PATH`. Go re-read it now with that in mind:

```bash
grep -n "NOTES_DB_PATH" app/database.py
```

## Your exercise

Using your Lesson 07 inventory and the pattern above:

1. In `app/main.py`, change `APP_ENV`, `APP_HOST`, `APP_PORT`, `LOG_LEVEL`, and `APP_SECRET` so each one is read via `os.environ.get("...", <current hard-coded value as the fallback>)`. Keep the current values as fallbacks for now, so the app still runs with zero configuration, exactly as it does today.
2. Decide what to do about `DATABASE_URL` in `app/database.py` — it's currently unused and inconsistent with the working `DB_PATH`/`NOTES_DB_PATH` pattern right next to it. Either remove it, or make it consistent with how `DB_PATH` already works. Justify your choice in a one-line comment.
3. Create a `.env` file in the project root with your own local values for every variable (real-looking but still non-sensitive training values are fine for `APP_SECRET` — never put a real credential in a learning project).
4. Create a **committed** `.env.example` file (no real values, just placeholders) documenting every variable the app now expects, e.g.:

   ```text
   APP_ENV=development
   APP_HOST=0.0.0.0
   APP_PORT=8000
   DATABASE_URL=sqlite:///./notes.db
   LOG_LEVEL=INFO
   APP_SECRET=change-me
   ```

5. Load `.env` before starting the app. You have two options — try the one that appeals to you more:
   * **Shell-only, no new dependency:** `set -a; source .env; set +a; uvicorn app.main:app --reload`
   * **`python-dotenv`:** add `python-dotenv` to your `dev`/runtime dependencies in `pyproject.toml`, `pip install -e ".[dev]"` again, and call `load_dotenv()` near the top of `app/main.py` before the config constants are read.
6. Confirm `.env` is covered by `.gitignore` (a project-level `.gitignore` already exists — check it) and run `git status` to confirm `.env` doesn't show up as a file git wants to track, while `.env.example` does.

## Questions for the learner

1. After your change, what happens if you run the app with **no** `.env` file and no environment variables set at all? Should that still work? (It should — you kept the original hard-coded values as fallbacks, on purpose.)
2. Why is it `.env.example`, and not `.env` itself, that gets committed to git?
3. Go back to Lesson 03's discovery — the app binding differently depending on how it's started. Does reading `APP_HOST`/`APP_PORT` from the environment in the `__main__` block fix that inconsistency, make it configurable-but-still-inconsistent, or something else? Be precise.

## Verification / checkpoint

```bash
pytest -v
git status
cat .gitignore
```

All tests should still pass — you didn't change any application behaviour, only *where configuration values come from*. `git status` should show `.env.example` (and your `app/`/`pyproject.toml` changes) as trackable, and should **not** show `.env`. If `.env` shows up in `git status` as something git wants to add, stop and fix your `.gitignore` before continuing.

## Recap

You've taken a hard-coded configuration block and made it environment-driven, using the exact pattern this codebase already demonstrated for `NOTES_DB_PATH`, and set up the `.env`/`.env.example` convention that every later deployment tool in this course will build on. Next, you'll think about what values should actually differ across environments — and why.
