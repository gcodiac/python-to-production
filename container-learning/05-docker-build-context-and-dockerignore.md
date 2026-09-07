# Lesson 05 — Docker Build Context and .dockerignore

**What you'll learn:** what actually gets sent to the Docker builder before a single instruction runs, and why that's a security question as much as a performance one.

## Goal

Understand the "build context," and add a `.dockerignore` that keeps it tight - matching commit `9f81601` on this branch.

## Why this matters in real DevOps/platform work

`COPY . .` doesn't copy from your filesystem directly - it copies from a *build context* that Docker already sent to the builder the moment you ran `docker build`. If that context includes your `.git` history, a real `.env` file, or a local SQLite database with real data in it, all of that got transmitted before you even reached the `COPY` instruction. Ignoring files at the *Dockerfile* level (e.g. skipping a `COPY`) doesn't undo that - the file was already sent.

## Concepts

* **Build context** — the directory (and everything in it, recursively, unless excluded) that gets packaged up and sent to the Docker build process as the starting point for any `COPY`/`ADD` instruction.
* **`.dockerignore`** — same syntax family as `.gitignore`, but it controls what enters the *build context* in the first place, not what enters an image layer. A file excluded here is never even available to `COPY .`.

## Investigation steps

### 1. See how big the build context is right now

```bash
du -sh .git .venv 2>/dev/null
```

Imagine both of those, plus `original/`, `learning/`, and `devops-learning/`, being sent to the builder on every single build without a `.dockerignore`.

### 2. Read this project's actual `.dockerignore`

```bash
cat .dockerignore
```

### 3. See it in action

```bash
docker build --progress=plain -t notes-app:context-check . 2>&1 | grep -i "transferring context"
```

## Questions for the learner

1. This project's `.dockerignore` excludes `.env` but keeps `!.env.example`. Why does the exception matter - what would go wrong if `.env.example` were accidentally excluded too?
2. `.dockerignore` also excludes `/original/`, `/learning/`, `/devops-learning/`, and `/container-learning/`. None of those are secrets - why exclude them anyway?
3. Suppose a teammate's local `.env` file, containing a real (if this were a real production app) database password, sat in the project root during a build with *no* `.dockerignore`. Even if the `Dockerfile` never has a `COPY .env` line, is that password still at risk? Where would you need to look to find out? (This is the exact question Lesson 21 answers properly - for now, just reason about it.)

## Expected observations

Without a `.dockerignore`, `docker build` would transfer megabytes of `.git` history, any local virtual environment, and every generated cache directory on *every single build* - slower, and a real information-disclosure risk if any of that context ever ends up inside a layer by accident (a careless `COPY . .` would grab all of it).

## Practical exercise

Temporarily rename `.dockerignore` to `.dockerignore.bak`, rebuild with `--progress=plain`, and compare the "transferring context" size to the run with `.dockerignore` in place. Restore the file afterwards (`git checkout -- .dockerignore` if you're not sure you got it back exactly right).

## Verification / checkpoint

You should be able to state, precisely: ".dockerignore controls the build context, not the final image" - and explain why both still matter even though they're different concerns.

## Recap

The build context is sent to the builder before a single Dockerfile instruction runs, and a tight `.dockerignore` is a real security and performance control, not housekeeping. Next: making Python dependencies actually reproducible, before improving the Dockerfile further.
