# Lesson 09 — Runtime Configuration and Secrets

**What you'll learn:** how the exact same image can behave differently per environment, using nothing but `docker run -e` - and why secrets specifically must never be baked in with `ARG`/`ENV`.

## Goal

Run the same built image twice with different configuration, and prove to yourself neither the environment nor the secret ever needed to be part of the image itself.

## Why this matters in real DevOps/platform work

This is Stage 1's whole "externalise configuration" lesson, continued: the same principle that applied to running the app directly on your machine applies, unchanged, to running it in a container. If anything, it matters *more* here - an image is a shared artefact that might get pushed to a registry, pulled by a dozen different environments, and inspected by anyone with pull access. Anything baked into it is baked in for everyone who ever pulls it.

## Concepts

```text
IMAGE
  +
RUNTIME CONFIGURATION
  =
RUNNING APPLICATION
```

* **Build time** — fixed at the moment `docker build` runs: the Python version, the locked dependency versions, the application code itself. These are the same for every container started from this image.
* **Runtime** — supplied fresh each time a container *starts*: `APP_ENV`, `APP_HOST`, `APP_PORT`, `DATABASE_URL`, `LOG_LEVEL`, `APP_SECRET`. These can differ between two containers running the exact same image.
* **Why not `ARG SECRET=...` or `ENV SECRET=...`?** A build `ARG` is recorded in the image's build history (`docker history`) unless you go out of your way with BuildKit secret mounts to avoid it - and an `ENV` is permanently part of every layer downstream of it, visible to `docker inspect` and to anyone who pulls the image. Both make the secret part of the *artefact* rather than part of a specific *run* of it - exactly backwards from what a secret needs.

## Investigation steps

### 1. Confirm the Dockerfile sets none of the six Stage 1 config values

```bash
grep -n "APP_ENV\|APP_HOST\|APP_PORT\|DATABASE_URL\|LOG_LEVEL\|APP_SECRET" Dockerfile
```

You should find nothing - the image is deliberately silent on all of them.

### 2. Run the same image two different ways

```bash
docker build -t notes-app:local .

docker run -d --name notes-dev -p 8001:8000 \
  -e APP_ENV=development \
  notes-app:local

docker run -d --name notes-staging -p 8002:8000 \
  -e APP_ENV=staging \
  -e LOG_LEVEL=WARNING \
  notes-app:local
```

### 3. Confirm the difference

```bash
curl http://127.0.0.1:8001/health
curl http://127.0.0.1:8002/health
```

### 4. Clean up

```bash
docker rm -f notes-dev notes-staging
```

## Questions for the learner

1. You just ran the *same* image (`notes-app:local`) and got two containers reporting two different `environment` values in `/health`. Where did that difference actually come from - the image, or the `docker run` command?
2. If you needed `APP_SECRET` set to something specific for one of these runs, would you add it to the `Dockerfile` and rebuild, or add it to the `docker run` command? Why is only one of those correct?
3. Suppose someone on your team, in a hurry, adds `ENV APP_SECRET=whatever-the-real-value-is` to the Dockerfile "just to get it working." What's now true about every copy of this image, anywhere it's ever pulled, that wasn't true before?

## Practical exercise

Try to break this deliberately: add a line `ENV LOG_LEVEL=DEBUG` to a scratch copy of the Dockerfile, rebuild, and then run a container that also passes `-e LOG_LEVEL=WARNING` at the command line. Which value wins - the image's `ENV`, or the run-time `-e`? (Runtime always overrides a build-time default `ENV` - but the fact that the image *declared* a default at all is exactly the sort of accidental coupling this project's real Dockerfile avoids entirely by not setting any of these six variables in the first place.)

## Verification / checkpoint

You should be able to point at the Dockerfile and correctly say "none of Stage 1's six configuration variables are set here, on purpose" - and explain, for `APP_SECRET` specifically, why that's a security requirement and not just tidiness.

## Recap

The same image, unmodified, behaves differently depending entirely on what's supplied at `docker run` time - and secrets specifically must only ever arrive that way, never baked into a layer. Typing `-e` flags by hand doesn't scale past a couple of variables, though - Lesson 12 introduces Compose to make this comfortable. First, a related runtime concern: where this app's actual data lives.
