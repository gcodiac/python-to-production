# Lesson 07 — Finding Hard-Coded Configuration

**What you'll learn:** how to systematically find every piece of environment-specific configuration buried in source code, and why that's a problem worth fixing before containerisation.

## Goal

Produce a complete inventory of every hard-coded configuration value in this application — including the ones neither `ruff` nor `bandit` flagged for you — with a note on why each one is a problem.

## Why this matters in real DevOps/platform work

This is the single most common thing you'll fix when taking over an application on its way to being containerised or deployed to the cloud. An application that hard-codes its database location, port, or environment name can only ever run one way — which means every different environment (dev, test, staging, production) needs its own *copy of the source code*, edited by hand. That's slow, error-prone, and it's exactly what environment variables exist to solve. You already have the tools' output from Lessons 05–06 — now you're going to go beyond what the tools reported, because tools don't catch everything.

## Concepts

* **Configuration living in code** — a value baked directly into a `.py` file, requiring a code change (and a new deployment) to alter.
* **The same artefact, different environments** — the professional goal is that the *exact same* tested code/package runs unchanged in dev, staging, and production; only its configuration differs.
* **Not everything hard-coded is a secret** — a hard-coded port number isn't dangerous the way a hard-coded password is, but it's still a configuration problem, and Lesson 06's security scanner won't flag most of these.

## Investigation steps

### 1. Re-read `app/main.py` from the top, specifically the constants block

```bash
sed -n '1,30p' app/main.py
```

### 2. Search deliberately for configuration-shaped values

Tools look for *patterns* (like variable names containing "password"). You need to look for *concepts* — values that would plausibly need to differ between environments:

```bash
grep -n "APP_ENV\|APP_HOST\|APP_PORT\|LOG_LEVEL\|APP_SECRET\|DATABASE_URL" app/*.py
```

### 3. Compare against the one existing *good* example

```bash
grep -n "NOTES_DB_PATH" app/database.py
```

This one already reads from an environment variable, with a sensible local fallback. Everything else you find in step 2 does not work this way yet — that's the gap you're identifying.

### 4. Check for inconsistency

You may notice more than one thing claiming to configure "where the database is." Find both, and work out whether they agree with each other or not.

## Questions for the learner

1. List every hard-coded configuration value you can find across `app/main.py` and `app/database.py`. For each, note: variable name, current value, and file:line.
2. Which of these did Lessons 05–06's tools actually flag for you, and which did you only find by reading the code and searching for concepts rather than patterns?
3. `app/database.py` has two things that both look like database configuration: `DB_PATH` and `DATABASE_URL`. Are they wired to the same thing? Which one does `get_connection()` actually use? What would you call the other one?
4. If someone deployed this application today to a production server with no environment variables set at all, what values would it silently use? Would that be safe?

## Commands to run

```bash
sed -n '1,30p' app/main.py
grep -n "APP_ENV\|APP_HOST\|APP_PORT\|LOG_LEVEL\|APP_SECRET\|DATABASE_URL\|NOTES_DB_PATH" app/*.py
```

## Expected observations

You should find six hard-coded configuration values in total: `APP_ENV`, `APP_HOST`, `APP_PORT`, and `LOG_LEVEL` (all module-level constants at the top of `app/main.py`), `APP_SECRET` (also in `app/main.py`), and `DATABASE_URL` (in `app/database.py`, defined but never actually used by `get_connection()` — a leftover, inconsistent with the working `DB_PATH`/`NOTES_DB_PATH` pattern right next to it). If nothing overrides these today, the app would silently run as `"development"`, bound to all interfaces, on port `8000`, at `INFO` log level, with a publicly-visible placeholder "secret" baked into the image or server you deploy it to — none of which is something you'd want to be true in production by default.

## Practical exercise

Write out a configuration inventory table: one row per value, columns for **name**, **current hard-coded value**, **file:line**, and **why this needs to be configurable per environment**. You'll use this table directly in the next lesson when you externalise these values.

## Verification / checkpoint

Your table should have exactly six rows. If you only found five, re-check `app/database.py` — one of them is easy to miss because it isn't actually being used anywhere yet.

## Recap

You've built a complete, evidence-based inventory of every hard-coded configuration value in this application — some caught by tooling, most found only by reading the code with the right question in mind ("would this need to differ between environments?"). Now you're ready to actually fix it.
