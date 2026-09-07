# Lesson 04 — Building the First Image

**What you'll learn:** the mechanics of `docker build` and `docker run`, using this project's actual first Dockerfile - imperfections included, on purpose.

## Goal

Build and run the very first version of this project's container, and see it work end to end, before any of the improvements later in this track.

## Why this matters in real DevOps/platform work

You need the basic build/run loop under your fingers before layering optimisation and hardening on top of it. You also need to see, concretely, that a Dockerfile can be "correct" (it builds, it runs, it serves traffic) while still having real, fixable problems - that distinction is the entire spine of this track.

## Investigation steps

### 1. Look at the first Dockerfile this project actually shipped

```bash
git show 3aa0b47:Dockerfile
```

Notice: `FROM python:3.12-slim` (a *floating* tag, not yet pinned - Lesson 07 fixes that), a single `COPY . .` of everything, and running as whatever user the base image defaults to.

### 2. Build it

```bash
git worktree add /tmp/notes-app-lesson04 3aa0b47
cd /tmp/notes-app-lesson04
docker build -t notes-app:naive .
```

(Using `git worktree` here checks out that one old commit into a separate directory without disturbing your actual working branch - a clean way to build historical versions of a Dockerfile for comparison. Remove it afterwards with `git worktree remove /tmp/notes-app-lesson04` from your main working directory.)

### 3. Run it

```bash
docker run -d --name notes-naive -p 8000:8000 notes-app:naive
```

### 4. Prove it actually works

```bash
curl http://127.0.0.1:8000/health
curl -X POST http://127.0.0.1:8000/notes -H "Content-Type: application/json" -d '{"title":"first container","content":"it works"}'
curl http://127.0.0.1:8000/notes
```

### 5. Clean up

```bash
docker rm -f notes-naive
cd ~/learning/Projects/python-to-production/fastapi-python/notes-app
git worktree remove /tmp/notes-app-lesson04
```

## Questions for the learner

1. Did `docker build` need network access? What was it downloading?
2. Look at `docker images` after your build - how large is `notes-app:naive`? You'll compare this number against the final, improved image in Lesson 16/16.
3. What user is the process running as inside this container? (`docker exec notes-naive whoami` if the container is still running.) Is that a problem yet, or just a fact you're noting for later?

## Practical exercise

Time your build twice in a row without changing anything (`time docker build -t notes-app:naive .` on this old commit). Then change one character in a comment inside `app/main.py`, and time a third build. Compare all three build times - which layers were reused from cache, and which had to redo work? You'll revisit this exact experiment in Lesson 07 once the Dockerfile is restructured for caching, and the difference will be dramatic.

## Verification / checkpoint

You should have a running container answering real API requests, and a recorded image size and build-time baseline to compare every later improvement against.

## Recap

You built and ran this project's very first, intentionally naive container image, and confirmed it genuinely works end to end. It has real problems - running as root, no dependency-layer caching, an unpinned base image, everything copied into the build context - and you'll fix every one of them, one commit at a time, starting now.
