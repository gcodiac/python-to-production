# Lesson 10 — Persistent Data and SQLite

**What you'll learn:** why a container's own filesystem is the wrong place for data that needs to outlive the container - matching commit `6588c38` - and how to prove data actually survives.

## Goal

Understand why `/data` exists in this image, why it's a Docker *named volume* rather than just "a folder," and prove notes survive a container being destroyed and recreated.

## Why this matters in real DevOps/platform work

"I restarted the container and all the data disappeared" is a rite of passage for anyone learning containers the hard way. A container's writable layer is exactly as temporary as the container itself - `docker rm` throws it away, no confirmation, no undo.

## Concepts

```text
container writable layer
        ↓
temporary - gone the moment the container is removed

application data
        ↓
must survive container replacement (deploys, restarts, crashes)
```

* **Named volume** — storage Docker manages on your behalf, identified by name (`notes-data` in this project), independent of any specific container. Multiple container runs can attach to the same named volume and see the same data.
* **Bind mount** (for contrast, not used here) — maps a *specific host path* into the container. This project deliberately uses a named volume instead: the data needs to persist, but doesn't need to live at any particular path on whatever host happens to be running it.

## Investigation steps

### 1. Read the Dockerfile's persistence-related lines

```bash
git show 6588c38 -- Dockerfile
```

### 2. Prove data survives, step by step

```bash
docker build -t notes-app:local .
docker volume create notes-data

docker run -d --name notes-persist -p 8000:8000 \
  -e DATABASE_URL="sqlite:////data/notes.db" \
  -v notes-data:/data \
  notes-app:local

curl -X POST http://127.0.0.1:8000/notes \
  -H "Content-Type: application/json" \
  -d '{"title":"survives recreation","content":"proof"}'
```

### 3. Destroy the container completely (not just stop it)

```bash
docker rm -f notes-persist
```

### 4. Recreate it from scratch, same volume

```bash
docker run -d --name notes-persist -p 8000:8000 \
  -e DATABASE_URL="sqlite:////data/notes.db" \
  -v notes-data:/data \
  notes-app:local

curl http://127.0.0.1:8000/notes
```

## Questions for the learner

1. In step 4, is this a "new" container or "the same" container as step 2, in Lesson 01's vocabulary? Is it the same *image*?
2. The note you created should still be there. Where was it actually stored while the container in step 2 existed, and where is it now that a completely different container is running?
3. Try `docker rm -f notes-persist` followed by `docker run` *without* `-v notes-data:/data` at all. Does your note come back? What does that prove about where the data really lived versus where you might have assumed it lived?

## Expected observations

The note created before the container was destroyed is still there after a brand-new container starts, as long as it's attached to the same named volume. Omit the volume flag, and you get a fresh, empty database instead - proving the persistence lived entirely in the volume, not in "the container" as a concept.

## Practical exercise

Run `docker volume inspect notes-data` and find the actual path on the Docker host where this volume's data lives on disk. You're not meant to ever touch that path directly - the point is just to see that it's real, ordinary storage Docker is managing for you, not magic.

## Verification / checkpoint

You should have direct, hands-on proof (not just this lesson's word for it) that a note survives `docker rm -f` followed by a fresh `docker run`, as long as the same named volume is attached both times.

## Recap

The application image must never contain live data - `/data`, backed by a named volume, is this project's explicit, deliberate answer to "where does data that needs to survive actually live?" Typing `-v`/`-e` flags by hand for all of this doesn't scale, though - Compose is next.
