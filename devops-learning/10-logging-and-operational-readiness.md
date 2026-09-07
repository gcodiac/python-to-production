# Lesson 10 — Logging and Operational Readiness

**What you'll learn:** why platform engineers care deeply about *where* an application's logs go and how verbose they are, and a real gap between two logging systems quietly running side by side in this app.

## Goal

Understand how this application currently logs, confirm where those logs actually go, and discover that "the app has a `LOG_LEVEL` setting" and "the app's log output is fully controlled by that setting" are not the same claim.

## Why this matters in real DevOps/platform work

You cannot operate what you cannot observe. When something goes wrong in production, logs are very often the *first and only* evidence you have. Platform teams standardise on: logs go to `stdout`/`stderr` (never to a file the app manages itself), log verbosity is controllable without a code change, and log format is consistent enough to be collected centrally. An application that logs to a local file, or that ignores its own configured log level in some code paths, will quietly cause real pain during an incident.

## Concepts

* **`stdout` vs `stderr`** — the two standard output streams every process has. Modern platforms (containers, orchestrators, systemd) capture both and forward them to centralised logging — this is *why* apps are expected to log there rather than to files.
* **Log level** — a threshold (`DEBUG`, `INFO`, `WARNING`, `ERROR`, ...) controlling which messages actually get emitted. Lower thresholds are noisier and more detailed; higher thresholds are quieter.
* **Application logs vs. access logs** — logs your own code emits (via Python's `logging` module) versus logs a web server/framework emits automatically for every request it handles. These are often two *separate* systems with independent configuration — which is exactly what you're about to find here.

## Investigation steps

### 1. Find where this app configures logging

```bash
grep -n "logging" app/main.py
```

### 2. Start the app and watch its console output

```bash
source .venv/bin/activate
uvicorn app.main:app --reload
```

In another terminal, make a couple of requests:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/notes
```

Watch the first terminal. What gets printed for each request?

### 3. Now try changing verbosity two different ways

Stop the app. First, try your app's own `LOG_LEVEL` (assuming you completed Lesson 08's exercise — if not, you can still observe Uvicorn's behaviour below):

```bash
LOG_LEVEL=DEBUG uvicorn app.main:app
```

Make a request again. Did the *request log lines* (the ones showing `GET /notes HTTP/1.1" 200 OK`) get any more or less detailed?

Now try Uvicorn's own, separate flag instead:

```bash
uvicorn app.main:app --log-level debug
```

## Questions for the learner

1. What produces the `INFO: 127.0.0.1:... - "GET /notes HTTP/1.1" 200 OK` lines you see for every request — is that coming from this application's own `logging.basicConfig(level=LOG_LEVEL)` call, or from Uvicorn itself?
2. Does changing your app's `LOG_LEVEL` environment variable actually change Uvicorn's access-log verbosity? What *does* control that?
3. Right now, does this application emit any log messages of its own (via `logger.info(...)`, `logger.warning(...)`, etc.) anywhere in `app/main.py`, beyond the one-time `logging.basicConfig()` setup call? What does that tell you about how useful `LOG_LEVEL` currently is in practice?
4. All of this output goes to your terminal by default — is that `stdout`, `stderr`, or does it depend? (You can check with `uvicorn app.main:app 1>/tmp/out.log 2>/tmp/err.log` and then looking at both files after making a request.)

## Commands to run

```bash
grep -n "logging" app/main.py
uvicorn app.main:app --log-level debug
uvicorn app.main:app 1>/tmp/out.log 2>/tmp/err.log &
curl http://127.0.0.1:8000/health
kill %1
cat /tmp/out.log /tmp/err.log
```

## Expected observations

The per-request access-log lines come from Uvicorn itself, configured by Uvicorn's own `--log-level` flag — not by this application's `LOG_LEVEL` constant, which only configures Python's root logger via `logging.basicConfig()`. Since the application currently doesn't call `logger.info(...)`/`logger.debug(...)` anywhere in its route handlers, `LOG_LEVEL` right now has almost no visible effect — it's wired up, but not yet *used* for anything meaningful. That's a realistic, common gap: configuration that exists but isn't fully connected to real behaviour. You should also find that Uvicorn's request logs land on `stderr` by default, which is normal — many well-behaved CLI tools do this — and is exactly why platform tooling captures both `stdout` and `stderr`, not just one.

## Practical exercise

Pick one meaningful place in `app/main.py` (for example, inside `create_note` or `delete_note`) and add a single `logger.info(...)` call that logs something operationally useful (e.g. which note ID was just deleted). Restart the app, trigger that action, and confirm your new log line appears — and confirm it stops appearing if you set a `LOG_LEVEL` higher than `INFO` (e.g. `LOG_LEVEL=WARNING`).

## Verification / checkpoint

```bash
pytest -v
```

Should still pass — logging additions shouldn't change behaviour. You should also be able to clearly explain, out loud, the difference between "Uvicorn's access logs" and "this application's own logs," and which environment variable controls which.

## Recap

You've found a real, common operational gap — a configured-but-barely-used log level — and learned that "the app has logging" and "the app's logging is fully controllable and useful" are different claims worth checking independently. Next, you'll look at how a platform actually knows whether this application is alive and ready to serve traffic.
