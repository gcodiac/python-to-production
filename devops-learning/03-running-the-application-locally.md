# Lesson 03 — Running the Application Locally

**What you'll learn:** setting up an isolated Python environment, starting the app, and using `ss`/`ps`/`curl` to confirm what it's actually doing at runtime — including a real inconsistency you're about to discover.

## Goal

Get the application running from a clean environment, exactly as a new engineer would, and confirm with real evidence (not assumptions) what host/port it's listening on.

## Why this matters in real DevOps/platform work

"It works on my machine" is the beginning of most production incidents, not the end of the investigation. Platform engineers need to reproduce an app's local runtime behaviour precisely, using isolated environments, before they can trust anything about how it'll behave elsewhere. You also need to get comfortable inspecting *running processes and open ports* directly — READMEs can be wrong or out of date; a running process cannot lie about what it's actually bound to.

## Concepts

* **Virtual environment (`venv`)** — an isolated Python installation so this project's dependencies don't collide with anything else on your machine.
* **Editable install (`pip install -e`)** — installs the project so code changes take effect immediately, without reinstalling.
* **Bind address** — the network interface + port a server listens on (e.g. `127.0.0.1:8000` vs `0.0.0.0:8000`). This distinction matters a great deal once you get to containers and networking.

## Investigation steps

### 1. Create an isolated environment and install the app

```bash
cd ~/learning/Projects/python-to-production/fastapi-python/notes-app
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

### 2. Start the app the way the README tells you to

```bash
uvicorn app.main:app --reload
```

Leave it running, and in a **second terminal** (remember to `source .venv/bin/activate` there too if you need the same tools), confirm it's actually listening:

```bash
ss -ltnp | grep 8000
```

### 3. Talk to it

```bash
curl -i http://127.0.0.1:8000/health
```

### 4. Check the process itself

```bash
ps aux | grep uvicorn
```

## Questions for the learner

1. According to `ss -ltnp`, what address is the app bound to — `127.0.0.1` or `0.0.0.0`? What's the practical difference between the two (who can reach the server in each case)?
2. Stop the app (`Ctrl+C`). Now start it a *different* way: `python -m app.main` (still inside the venv). Run `ss -ltnp | grep 8000` again. Is the bind address the same as before?
3. Why do you think those two ways of starting the exact same application produced different results? (Hint: re-read `app/main.py`, specifically the bottom of the file.)

## Commands to run

```bash
source .venv/bin/activate
uvicorn app.main:app --reload
# --- separate terminal ---
ss -ltnp | grep 8000
curl -i http://127.0.0.1:8000/health
ps aux | grep uvicorn
```

## Expected observations

Running `uvicorn app.main:app --reload` from the CLI binds to Uvicorn's own default, `127.0.0.1:8000` — reachable only from the same machine. Running `python -m app.main` instead executes the `if __name__ == "__main__":` block at the bottom of `app/main.py`, which calls `uvicorn.run()` with a hard-coded host/port baked into the source. Depending on what those hard-coded values are, that can produce a **different bind address than the documented way of starting the app** — the same codebase behaving inconsistently depending on how it's launched. That's exactly the kind of surprise you want to catch now, on your laptop, rather than after it's deployed somewhere.

## Practical exercise

1. Confirm both startup methods work and note the exact bind address `ss` reports for each.
2. Without changing any code yet, write down in your notes: which startup method matches what the README documents? Which one would you *not* want a container or systemd unit to accidentally use without you knowing what address it binds to?
3. Stop the app (`Ctrl+C`, both terminals if needed) before moving on.

## Verification / checkpoint

You should have two different, evidence-based bind addresses written down (from `ss`, not from reading the code alone), plus a working `curl` response from `/health`. If `curl` fails, check that the app is actually still running and that you're hitting the right port.

## Recap

You ran the application two different ways and used `ss` to observe a real, evidence-based difference in network behaviour between them — not something you'd have caught by reading the README alone. Keep that host/port discrepancy in mind; you'll deal with it properly once you reach configuration in Lesson 07.
