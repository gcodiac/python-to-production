# Lesson 12 — Docker Compose for Local Running

**What you'll learn:** how `compose.yaml` replaces a long, error-prone `docker run` command with one declarative, repeatable file - matching commit `f3bd907`.

## Goal

Run this project's full stack (build, port mapping, environment, persistent volume, health check) with one command, and understand why `compose.yaml` is a genuinely different concern from the `Dockerfile`.

## Why this matters in real DevOps/platform work

By Lesson 10, running this container correctly meant remembering a `docker run` command with a build step, a port mapping, several `-e` flags, and a volume mount - and getting `APP_HOST` and `DATABASE_URL` right by hand every time. That doesn't scale past one person's memory. Compose exists precisely so "how do I run this locally" has one, versioned, correct answer that everyone on a team shares.

## Concepts

```text
Dockerfile
    =
how the image is built

Compose
    =
how a container from that image is configured and run
```

* **Service** — Compose's word for one container-shaped thing to run (this project has exactly one: `notes-app`).
* **`.env` auto-loading** — Compose automatically reads a `.env` file in the same directory as `compose.yaml` for `${VAR}` substitution. This is the *same* `.env` file Stage 1 taught you to create with `cp .env.example .env` - one file, two different consumers (your app's own `python-dotenv` call, and Compose's variable substitution).

## Investigation steps

### 1. Read the file

```bash
cat compose.yaml
```

### 2. Notice what's hardcoded versus substituted

```bash
grep -n "APP_HOST\|DATABASE_URL\|\${" compose.yaml
```

### 3. Run it

```bash
cp .env.example .env    # if you haven't already, from Stage 1
docker compose up --build
```

### 4. Confirm it, in a second terminal

```bash
curl http://127.0.0.1:8000/health
docker compose ps
```

### 5. Stop it

```bash
docker compose down
```

## Questions for the learner

1. `compose.yaml` hardcodes `APP_HOST: "0.0.0.0"` and `DATABASE_URL: "sqlite:////data/notes.db"` directly, rather than substituting them from `.env` the way `APP_ENV` and `LOG_LEVEL` are. Re-derive why, from Lesson 09's build-time-vs-runtime reasoning and Lesson 10's persistence reasoning - what would go wrong if these two specifically came from your bare-metal `.env` instead?
2. `docker compose down` (without `-v`) versus `docker compose down -v` - which one deletes the named volume, and therefore your notes? Try the safe one first, restart with `docker compose up`, and confirm your data is still there.
3. Compose's `healthcheck:` block here duplicates the image's own `HEALTHCHECK` almost exactly. Given that duplication, when would overriding it in Compose actually be worth doing rather than just relying on the image's default?

## Practical exercise

Change `APP_PORT` in your local `.env` file to `8080`, then `docker compose up --build` again. Confirm the app is now reachable at `http://127.0.0.1:8080/health` - and confirm (by checking `docker compose ps` or `docker inspect`) that *inside* the container, it's still listening on port 8000 exactly as before. That gap between "host-side port" and "container-side port" is exactly what `"${APP_PORT:-8000}:8000"` in `compose.yaml` is doing.

## Verification / checkpoint

You should be able to bring the whole stack up and down with `docker compose up`/`docker compose down`, and explain precisely which of the six Stage 1 config values come from your `.env` file and which are deliberately fixed in `compose.yaml` itself, and why.

## Recap

`compose.yaml` turns "how do I run this correctly" into one shared, versioned file instead of a command someone has to remember precisely. With building and running solid, it's time to start pointing real tooling - starting with a Dockerfile linter - at what's been built so far.
