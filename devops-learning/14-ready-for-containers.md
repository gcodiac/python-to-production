# Lesson 14 — Ready for Containers

**What you'll learn:** why everything you just did was necessary preparation for containerisation specifically, and what to expect from the next stage of this course.

## Goal

Connect each piece of work from Lessons 00–12 directly to a concrete reason it matters once this application is packaged into a container — without actually writing a `Dockerfile` yet.

## Why this matters in real DevOps/platform work

Containerising an application you don't understand just produces a container you don't understand, faster. Every lesson in this track maps onto a real, specific decision you'll have to make when writing this app's eventual `Dockerfile` and `docker-compose.yml`. Seeing those connections explicitly, before you write a single line of container configuration, is what separates "I copied a Dockerfile template from the internet" from "I know why this Dockerfile looks the way it does."

## How this track maps onto containerisation

| What you did | Why it matters for containers |
|---|---|
| Lesson 01–02: mapped routes, static files, and the database boundary | You now know exactly what a container image needs to include (`app/`, its dependencies) and what it must *not* assume exists locally (there's no separate DB server to reach). |
| Lesson 03: found two different bind addresses depending on startup method | Containers need a predictable, explicit start command and a known listening address — you now know exactly what to pin down. |
| Lesson 04: separated runtime dependencies from dev-only dependencies | A production image should install `fastapi`/`uvicorn`, not `pytest`/`ruff`/`bandit` — you already know precisely which is which. |
| Lesson 05–06: ran linting and security scanning locally | These same commands are what you'll wire into a CI pipeline (a later track) to run automatically on every change — you already know how to run and read them. |
| Lesson 07–09: found and externalised hard-coded configuration | This is *exactly* what becomes `docker run -e APP_ENV=production ...` or an `--env-file`, and later a Kubernetes `ConfigMap`/`Secret` — the mechanism doesn't change, only what supplies the environment variables does. |
| Lesson 10: confirmed logs go to stdout/stderr | This is precisely what `docker logs` captures — an app that logged to a local file instead would lose its logs the moment its container was removed. |
| Lesson 11: found the gap between "alive" and "actually working" | This becomes a container `HEALTHCHECK` instruction (or a Kubernetes liveness/readiness probe) — you already know what this app's `/health` endpoint does and does not currently verify. |
| Lesson 13: completed an honest readiness review | This is the review you'd want to redo, briefly, right before any major infrastructure change — containerisation included. |

## Questions for the learner

1. Pick any two rows in the table above and explain, in your own words, the connection — not just what you did, but *why a container specifically* needs that.
2. If you skipped straight to writing a `Dockerfile` on day one, without this track, what's the most likely thing that would have gone wrong first?
3. What is still genuinely *not* solved yet, that a future stage of this course will need to address (hint: think about where `.env` files live relative to a container image, and what happens to `APP_SECRET` once there's no developer's laptop involved at all)?

## Practical exercise

Write a short paragraph — this is the last piece of writing in this track — describing this application's current state to an imaginary teammate who's about to containerise it. Use your Lesson 13 checklist as source material. Be specific about anything you'd still flag as a caveat.

## Verification / checkpoint

You should be able to answer, without opening any file: what does this app need to run, what does it listen on, how is it configured, where do its logs go, and how would something external know if it's actually working. If any of those feel shaky, that's worth five minutes back in the relevant lesson before you consider this track complete.

## What comes next

The next stage of this course picks up exactly here, and covers containerisation properly:

* Writing a `Dockerfile` for this exact application — choosing a base image, installing only runtime dependencies, and setting an explicit, correct start command (directly informed by what Lesson 03 taught you about this app's two different bind addresses).
* Passing configuration into a container the right way — `docker run --env-file`, and why a `.env` file is used differently for local Docker development versus how real secrets are handled later.
* Wiring the `/health` endpoint from Lesson 11 into a container `HEALTHCHECK` instruction, and discussing its shallow-vs-deep limitation in that context.
* Introducing `docker-compose.yml` to run the app (and, later, a real database) together as a small local stack.
* A first look at what changes, if anything, about SQLite as a data store once the app runs inside a container with an ephemeral filesystem.

That stage isn't part of this track — you've done the preparation work; building the container itself comes next.

## Recap

You've taken an unfamiliar, inherited FastAPI application and made it genuinely ready to containerise: understood, tested, statically and security analysed, configured through the environment rather than the source code, and reviewed for basic operational readiness. That's the real job of the pre-containerisation phase of any platform engineering effort — and it's exactly the foundation the next stage of this course will build on.
