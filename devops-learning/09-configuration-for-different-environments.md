# Lesson 09 — Configuration for Different Environments

**What you'll learn:** why the *same* application artefact should behave differently in development, test, staging, and production purely through configuration — and a gentle, practical introduction to the idea behind the Twelve-Factor App's config principle.

## Goal

Design (on paper — you don't need to deploy anything yet) what should differ between environments for this application, and understand why "editing the source code per environment" is something you now know how to avoid entirely.

## Why this matters in real DevOps/platform work

A huge amount of platform engineering is, at its core, "make sure the exact same build artefact runs correctly and safely everywhere it needs to run." If different environments need different *code*, you've lost that guarantee — you're now testing one thing and shipping another. This is one of the most consequential ideas in this entire track, and it's simple once you've actually done the exercise in Lesson 08.

## Concepts

* **Environments** — the distinct contexts an application runs in over its life: typically `development` (your laptop), `test`/`ci` (automated test runs), `staging` (a production-like environment for final checks), `production` (real users, real data).
* **The same artefact principle** — build your application/package once, and deploy that *exact* build to every environment, changing only its configuration. You do **not** rebuild the code differently per environment.
* **The Twelve-Factor App, Factor III (Config)** — a widely-referenced set of practices for building deployable web apps. Factor III specifically says: store config in the environment, strictly separate from code, because config varies across environments and code does not. You've already been implementing this since Lesson 08 — this lesson just names the principle and shows you why it scales. (You don't need to read the full Twelve-Factor document for this course, but it's worth knowing it exists: <https://12factor.net/config>.)

## Investigation steps

### 1. Look at what your tests already do differently

You've been running `pytest` since Lesson 05. Go look at how it configures the database, *before* the app even starts:

```bash
head -5 tests/test_notes.py
```

### 2. Notice this is the same mechanism, applied to a different environment

That line sets `DATABASE_URL` to a temporary SQLite file before importing the app — meaning the **test** environment gets its own isolated database, using the *exact same application code* as development or production, purely through an environment variable. You've been looking at a working example of this whole lesson since Lesson 04.

## Questions for the learner

1. Besides the database location, name at least three of the configuration values from your Lesson 07/08 work that would plausibly need *different* values in `production` than they have in `development`. For each, say what you'd actually set it to and why.
2. Would you want `LOG_LEVEL=DEBUG` in production? What are the trade-offs (think about both usefulness during an incident and cost/noise/performance)?
3. Should `APP_SECRET` have the *same* value in every environment, or a different one per environment? What would go wrong if staging and production shared one?
4. `APP_ENV` itself is one of your configuration values. What might application code (now or in the future) reasonably *do* differently based on its value? (You don't need to implement anything — just describe a plausible example.)

## Practical exercise

Write out two `.env`-style blocks side by side in your notes — one representative of `development`, one representative of `production` — using the six variables from your inventory. They don't need to be real, deployable values; the point is to show they'd genuinely differ:

```text
# development                    # production
APP_ENV=development               APP_ENV=production
APP_HOST=127.0.0.1                APP_HOST=0.0.0.0
APP_PORT=8000                     APP_PORT=8000
DATABASE_URL=sqlite:///./notes.db DATABASE_URL=<a real production DB location>
LOG_LEVEL=DEBUG                   LOG_LEVEL=WARNING
APP_SECRET=dev-placeholder        APP_SECRET=<a real secret, from a secret manager, never in a file>
```

Then write two sentences: one explaining why `APP_SECRET`'s production value shouldn't live in a `.env` file at all in a real production system (a preview of secret management, which is out of scope for this track but worth naming), and one explaining what stays *identical* across every column above (hint: it's everything that isn't in this table).

## Verification / checkpoint

You should be able to explain, without hesitation, why this application's `app/`, `tests/`, and `pyproject.toml` never need to change between development, test, and production — only the values supplied at startup do. If you find yourself wanting to edit `app/main.py` to "make it work in production," that's a sign the configuration isn't fully externalised yet — go back to Lesson 08.

## Recap

You've connected the environment-variable work from Lesson 08 to the bigger idea it serves: one build, many environments, differing only by configuration — and you've seen this pattern already quietly at work in this project's own test suite since long before you noticed it. Next, you'll look at what the application does once it's actually handling requests: logging.
