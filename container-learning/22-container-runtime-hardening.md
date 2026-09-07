# Lesson 22 — Container Runtime Hardening

**What you'll learn:** read-only root filesystems, dropped Linux capabilities, and `no-new-privileges` - matching commit `2d173b4` - and the one question that determines whether any of this breaks the app.

## Goal

Understand and verify this project's four runtime hardening controls in `compose.yaml`, and be able to answer, precisely, what this application actually needs permission to write.

## Why this matters in real DevOps/platform work

Non-root (Lesson 08) is one axis of hardening. It's not the only one. A non-root process can still write files it shouldn't, hold Linux capabilities it doesn't need, or gain privileges through a setuid binary if one happens to be reachable. The controls in this lesson close those gaps - but only if you first correctly answer "what does this app actually need to do?"

## Concepts

* **`read_only: true`** — the container's own filesystem (everything from the image, plus its normal writable layer) becomes read-only. Nothing outside an explicitly mounted volume can be written to.
* **`cap_drop: [ALL]`** — Linux capabilities are fine-grained permissions (`CAP_NET_BIND_SERVICE`, `CAP_SYS_ADMIN`, dozens more) that root processes normally hold by default inside a container. Dropping all of them removes privileges this app never needed in the first place.
* **`security_opt: [no-new-privileges:true]`** — prevents any process inside the container from gaining *more* privileges than it started with (e.g. via a setuid binary), even if one were somehow present.
* **The one question that matters:** *what does this application actually need permission to write?* Answer that honestly before enabling `read_only`, or you'll just get a confusing runtime crash instead of a hardened container.

## Investigation steps

### 1. Read the actual configuration

```bash
git show 2d173b4 -- compose.yaml
```

### 2. Answer the one question, for this specific app

* SQLite's database file - `/data/notes.db` - **must** remain writable. That's why `/data` is a separate named volume mount (Lesson 10), unaffected by `read_only: true` on the container's own filesystem.
* Anything else? Python's own bytecode cache (`__pycache__`) would normally want to write next to `.py` files - but `PYTHONDONTWRITEBYTECODE=1` (Lesson 07) already disables that, so a read-only `/opt/venv` doesn't cause even a silent failed-write attempt.
* `/tmp` — provided as a `tmpfs` (in-memory, ephemeral, writable) mount specifically because *some* library or the interpreter itself might reasonably want scratch space there, even though this app doesn't use it directly today.

### 3. Run it and verify hardening didn't break anything

```bash
docker compose up --build
curl http://127.0.0.1:8000/health
curl -X POST http://127.0.0.1:8000/notes -H "Content-Type: application/json" -d '{"title":"hardened","content":"still works"}'
```

### 4. Prove the read-only filesystem is actually enforced

```bash
docker compose exec notes-app touch /app/should-fail
```

This should fail with a permission/read-only filesystem error - if it doesn't, `read_only: true` isn't actually taking effect.

## Questions for the learner

1. If this app tried to write anywhere other than `/data` or `/tmp`, what would you expect to happen with `read_only: true` enabled? Is that a crash, or a clean, correctly-rejected write?
2. Why is `cap_drop: [ALL]` safe here specifically? What would you need to check before doing this to a *different* application (hint: does it need to bind to a privileged port below 1024, or do anything else that genuinely needs a specific capability)?
3. `no-new-privileges` protects against a very specific escalation path. In your own words, what is that path, and why does a non-root user (Lesson 08) alone not already fully close it?

## Practical exercise

Temporarily comment out `read_only: true` in a scratch copy of `compose.yaml`, confirm the app still runs, then restore it and confirm `docker compose exec notes-app touch /app/should-fail` fails again as expected. This is the same "prove it's doing real work" pattern from Lesson 08's non-root check.

## Verification / checkpoint

You should have hands-on proof (a failed `touch` command) that `read_only: true` is genuinely enforced, and a working, unaffected application (`/health`, note creation) proving the hardening didn't collaterally break anything real.

## Recap

Four runtime controls, all answering "what does this app actually need, and nothing more" - and all verified, not just declared. Next: proving the whole built artefact actually works, end to end, as its own dedicated test.
