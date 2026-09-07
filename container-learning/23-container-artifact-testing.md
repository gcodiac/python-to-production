# Lesson 23 — Container Artifact Testing

**What you'll learn:** why `docker build` succeeding proves almost nothing, and how this project's `scripts/container-smoke-test.sh` proves the rest - matching commit `5f7e402`.

## Goal

Run this project's container smoke test, and understand exactly what each of its checks proves that a successful build alone does not.

## Why this matters in real DevOps/platform work

A `Dockerfile` with a typo in an environment variable name, a broken health check, or accidentally-root permissions can all still `docker build` successfully - a build only proves the *instructions* were syntactically followable, not that the *resulting container* actually does what you need.

## What this script actually checks

```bash
cat scripts/container-smoke-test.sh
```

```text
image builds                          <- prerequisite, checked by `make build` before this runs
container starts
health endpoint responds
notes API works (create + read back)
static dashboard works
database writes work
database persists across container recreation
container runs as non-root
container stops cleanly
no secret appears in the image's own config
```

Every one of these is a real, previously-discussed lesson in this track, now assembled into one repeatable script rather than something you re-verify by hand every time.

## Investigation steps

### 1. Build first (the script assumes an image already exists)

```bash
docker build --build-arg GIT_REVISION=$(git rev-parse --short HEAD) -t notes-app:local .
```

### 2. Run the smoke test

```bash
./scripts/container-smoke-test.sh
```

### 3. Read the script's cleanup trap

```bash
grep -A3 "^cleanup()" scripts/container-smoke-test.sh
```

## Questions for the learner

1. The script's very first real check is "no secret appears in the image's own config," using `docker inspect`, not a simple string grep through the filesystem. Given Lesson 21's "deleted secrets still exist in old layers" lesson, why is checking `docker inspect`'s reported `Env` the *right* check here specifically, for *this* project (which never bakes a secret in at all, rather than one that bakes one in and then tries to remove it)?
2. The persistence check (`docker rm -f` followed by a fresh `docker run` on the same named volume) is the exact same proof from Lesson 10, just automated. Why does it belong in *every* run of this script, rather than being something you only checked once by hand and trusted forever?
3. What does this script *not* check, that Lessons 19-20's Trivy scans cover instead? Why do both categories - functional smoke testing and security scanning - need to exist as separate steps, rather than one script trying to do everything?

## Practical exercise

Deliberately break something small and predictable - change `EXPOSE 8000` to `EXPOSE 8080` in a scratch copy of the `Dockerfile` (without changing the `CMD`'s `--port` argument, so the app still actually listens on 8000 internally) - rebuild, and run the smoke test. Does it catch the mismatch? If not, what would you add to the script to make it catch exactly this kind of drift between what the image *documents* (`EXPOSE`) and what it *actually does*?

## Verification / checkpoint

You should have run this script yourself, end to end, against a real built image, and gotten "All container smoke tests passed" - or, if something failed, understood exactly which specific guarantee broke and why.

## Recap

`docker build` succeeding is a starting point, not a finish line - this script is what actually earns the label "this artefact works." Next: metadata that helps anyone (including future you) understand what this image is, without needing to already know.

## Testing the same artefact against a second database

`scripts/container-smoke-test.sh` exercises the image against SQLite. Its sibling, `scripts/postgres-smoke-test.sh`, runs the *same image* against a real PostgreSQL server started for the duration of the script:

```bash
make build
make container-test    # SQLite
make postgres-test     # PostgreSQL - same image, no rebuild
```

The PostgreSQL script makes one claim the SQLite one cannot: that the deployable artefact works against a networked, client/server database. It proves it by creating a note through the HTTP API and then reading that row back with `psql`, a client that has nothing to do with the application. A `postgres` container merely running alongside the app would be no evidence at all.

Note what neither script does: rebuild. Testing a *different* image from the one you intend to release tests the wrong thing.
