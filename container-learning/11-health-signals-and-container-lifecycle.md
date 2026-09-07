# Lesson 11 — Health Signals and Container Lifecycle

**What you'll learn:** how a container reports its own health, and why "the process exists" and "the application is healthy" are different claims - matching the `HEALTHCHECK` half of commit `d45b40f`.

## Goal

Understand and observe this project's `HEALTHCHECK` instruction, using the exact same `/health` endpoint from devops-learning Lesson 11 - now wired into the container runtime itself.

## Why this matters in real DevOps/platform work

`docker ps` showing `Up 2 minutes` tells you the process hasn't crashed. It tells you nothing about whether that process is actually serving correct responses. Orchestrators (Docker Compose, Kubernetes, ECS, and everything else built on this idea) all need a real signal distinguishing "running" from "actually working," and `HEALTHCHECK` is Docker's version of that signal.

## Concepts

```text
process exists
    !=
application healthy
```

* **`HEALTHCHECK`** — a command Docker runs periodically *inside* the container. Its exit code (0 = healthy, non-zero = unhealthy) feeds `docker ps`'s STATUS column and `docker inspect`'s `.State.Health` field.
* **Docker health checks vs. Kubernetes liveness/readiness probes** — related ideas, not identical mechanisms. Docker has one `HEALTHCHECK` per image/container. Kubernetes deliberately splits the concept into a *liveness* probe (should this be restarted?) and a *readiness* probe (should this receive traffic right now?) - a distinction this project doesn't need yet, since it isn't running under Kubernetes. Worth knowing the vocabulary exists; not worth implementing prematurely.

## Investigation steps

### 1. Read the instruction

```bash
git show d45b40f -- Dockerfile
```

### 2. Watch it work

```bash
docker build -t notes-app:local .
docker run -d --name notes-health -p 8000:8000 notes-app:local
docker ps
```

`docker ps`'s STATUS column will show `(health: starting)` at first, then flip to `(healthy)` once the first successful check lands.

### 3. Inspect the health check's own history

```bash
docker inspect --format='{{json .State.Health}}' notes-health | python3 -m json.tool
```

## Questions for the learner

1. This project's `HEALTHCHECK` runs a Python one-liner (`urllib.request.urlopen(...)`) instead of `curl`. Why does that matter for what ends up in the final image? (Reconnect this to Lesson 07's "no package installer at runtime" reasoning - the same "don't add things you don't need" logic applies here.)
2. The `HEALTHCHECK` has `--start-period=5s`. What problem would you hit without it, given that this app needs a moment after startup before `/health` is reliably answering?
3. Stop the app from responding correctly somehow (for a safe experiment: `docker exec notes-health kill 1` sends SIGTERM to the main process, which should - if Lesson 15's shutdown handling works - cause the container to exit rather than hang). Watch what `docker ps` reports as the container goes down.

## Practical exercise

Deliberately break the health check to see it actually fail: `docker exec -u 0 notes-health python -c "print('nope')"` won't affect anything (it's a one-off exec, not the health check itself) - instead, try starting a container with an intentionally wrong port mapping expectation, or simply watch `docker inspect`'s health log accumulate a few consecutive checks over a couple of minutes, and read the actual output each one recorded.

## Verification / checkpoint

You should have seen, with your own eyes, `docker ps` transition from `(health: starting)` to `(healthy)` for a real running container - not just read that it does.

## Recap

The container now actively reports its own health, using the exact endpoint devops-learning built for this exact purpose. Time to make running all of this comfortable with Docker Compose.
