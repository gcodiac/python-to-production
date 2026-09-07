# Lesson 15 — Signals and Graceful Shutdown

**What you'll learn:** what `docker stop` actually does, why `CMD` being written as a JSON array (not a bare string) matters for it, and how to verify shutdown behaviour yourself - matching the exec-form half of commit `d45b40f`.

## Goal

Understand PID 1, SIGTERM, and the shutdown grace period, and prove this container shuts down cleanly and quickly.

## Why this matters in real DevOps/platform work

A container that doesn't shut down cleanly either hangs until Docker forcibly kills it (losing whatever grace period your application logic needed to finish in-flight requests) or, worse, silently doesn't pass along the signal to the process that actually needs to see it. Both are common, and both are avoidable with one detail: how `CMD` is written.

## Concepts

* **PID 1** — the first process started inside a container's own process namespace. It has special responsibilities in Linux (reaping zombie processes) and is specifically who receives the signal `docker stop` sends.
* **SIGTERM** — the signal `docker stop` sends first, asking a process to shut down *gracefully*. A well-behaved process catches this and exits cleanly on its own terms (finishing in-flight work, closing connections).
* **Shutdown grace period** — Docker waits (10 seconds, by default) after sending SIGTERM before giving up and sending SIGKILL, which cannot be caught or ignored - an immediate, forceful stop.
* **Exec form vs. shell form CMD** — `CMD ["uvicorn", "app.main:app", ...]` (a JSON array - exec form) runs `uvicorn` directly as PID 1. `CMD uvicorn app.main:app ...` (a bare string - shell form) actually runs `/bin/sh -c "uvicorn app.main:app ..."` - meaning the *shell* becomes PID 1, and `uvicorn` is its child. `docker stop`'s SIGTERM goes to PID 1 - the shell - which may or may not bother forwarding it to `uvicorn` at all, depending on the shell and how it's invoked.

## Investigation steps

### 1. Confirm this project's `CMD` is exec form

```bash
grep -A1 "^CMD" Dockerfile
```

### 2. Confirm what's actually PID 1 inside a running container

```bash
docker run -d --name notes-signal -p 8000:8000 notes-app:local
docker exec notes-signal ps -o pid,comm
```

### 3. Time a clean stop

```bash
time docker stop notes-signal
```

### 4. Clean up

```bash
docker rm notes-signal
```

## Questions for the learner

1. What did `ps -o pid,comm` show as PID 1 inside the container - was it `uvicorn` directly, or a shell?
2. How many seconds did `docker stop` actually take? Was it close to instant (graceful shutdown succeeded quickly) or close to 10 seconds (Docker likely had to wait out the grace period and force-kill)?
3. As a deliberate, temporary experiment: change `CMD` in a scratch copy of the Dockerfile to the shell form - `CMD uvicorn app.main:app --host 0.0.0.0 --port 8000` (no brackets, no quotes) - rebuild, and repeat steps 2-3. Does PID 1 change? Does the stop time change?

## Expected observations

With the real exec-form `CMD`, `uvicorn` itself is PID 1, and `docker stop` should complete in well under a second - `uvicorn`'s own SIGTERM handling shuts it down immediately and cleanly. With the shell-form experiment, PID 1 becomes `/bin/sh`, and depending on your shell, `docker stop` may take the full ~10 second grace period before Docker gives up and force-kills the container - a real, measurable difference from one syntax choice.

## Practical exercise

Restore the real Dockerfile (don't keep the shell-form experiment). Run the container once more, and this time send the request while it's running, then immediately `docker stop` it, and watch the container's logs (`docker logs notes-signal` before removing it) for Uvicorn's own shutdown messages - proof it saw the signal and exited on its own terms, not by being forcibly killed.

## Verification / checkpoint

You should have a timed, real `docker stop` under one second, and be able to explain - using PID 1 and SIGTERM specifically - why the exec-form `CMD` is what makes that possible.

## Recap

`docker stop` sends SIGTERM to PID 1, and exec-form `CMD` is what guarantees that's actually your application, not an intermediary shell that might not pass it along. No process supervisor was needed here - a single, well-behaved process handling its own signals is enough for this app. Next: actually looking inside the image you've built.
