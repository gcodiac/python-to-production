# Lesson 03 — Choosing a Base Image

**What you'll learn:** how to pick a base image deliberately - tags, digests, distro variants - instead of copy-pasting `FROM python:latest` and moving on.

## Goal

Choose, and be able to justify, the exact base image this project uses: `python:3.12.14-slim-bookworm`, not `python:latest`, not Alpine, not a bare digest with no readable tag.

## Why this matters in real DevOps/platform work

The base image is the foundation of your entire supply chain (Lesson 23-24) - every OS package it contains is now something your container ships, patches, and gets scanned for. Picking it carelessly is one of the most common root causes of "why does our container have 40 vulnerabilities we can't explain."

## Concepts

* **Tag** — a human-readable pointer to a specific image, e.g. `3.12-slim-bookworm`. Tags are **mutable** - `python:3.12-slim-bookworm` points to whatever the latest 3.12.x patch build is *today*, and will point somewhere else next month.
* **`latest`** — the most mutable, least informative tag possible. `python:latest` today might be Python 3.14 on Debian trixie; next year it's something else entirely, silently, the next time anyone rebuilds.
* **Digest** — a `sha256:...` content hash that identifies one specific, immutable image, forever. A tag is a moving pointer; a digest is the thing it points to *right now*.
* **Distro variant** — the same Python version is published on top of different Linux bases: full `bookworm` (Debian, larger, more OS tooling), `slim-bookworm` (Debian, stripped down), `alpine` (musl libc, much smaller, different package ecosystem).
* **Reproducibility vs. updateability** — pinning to a digest is maximally reproducible (it can never silently change) but you must manually decide when to move to a newer, patched digest. Pinning to a floating tag updates automatically but can change under you without warning.

## Investigation steps

### 1. See how many tags exist for one Python version

```bash
curl -s "https://hub.docker.com/v2/repositories/library/python/tags/?page_size=100&name=3.12" \
  | python3 -c "import json,sys; [print(r['name']) for r in json.load(sys.stdin)['results']]" \
  | sort
```

### 2. Get the digest a specific tag currently resolves to

```bash
curl -s "https://hub.docker.com/v2/repositories/library/python/tags/3.12.14-slim-bookworm" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['digest'])"
```

(Once you have Docker running, `docker inspect --format='{{index .RepoDigests 0}}' python:3.12.14-slim-bookworm` after a pull shows the same thing locally.)

## Questions for the learner

1. Why does this project use `python:3.12.14-slim-bookworm` specifically, rather than `python:3.12-slim-bookworm` (no patch version) or `python:latest`?
2. Why *not* Alpine, even though it produces a noticeably smaller image? (Hint: Alpine uses musl libc instead of glibc - what could that affect for a project using `uvicorn[standard]`, which pulls in C-extension-backed packages like `uvloop` and `httptools`?)
3. What's the actual trade-off of pinning the `Dockerfile`'s `FROM` line to a full digest instead of a tag like this project does? What do you gain, and what do you have to now do manually that a floating tag would have done for you?

## Expected observations

`slim-bookworm` gives you a real, well-supported glibc-based Debian userland (so prebuilt Python wheels - including the C-extension ones `uvicorn[standard]` depends on - install without surprises) at a fraction of the size of the full `bookworm` image, without Alpine's musl-libc compatibility risk for a project this small chose not to test against. An explicit patch version (`3.12.14`, not just `3.12`) means you know exactly what you're building on and update it as a deliberate choice, not by accident on your next rebuild.

## Practical exercise

Run the digest-lookup command above for `python:3.12.14-slim-bookworm` and write down the digest you get. Compare it to the one recorded as a comment at the top of this project's `Dockerfile`. Are they the same? (They should be, as of when this project was built - if Debian ever rebuilds that exact tag for a security patch, they could eventually differ, which is itself the lesson: even a specific patch-version *tag* isn't perfectly immutable the way a digest is.)

## Verification / checkpoint

You should be able to justify this project's base image choice in one paragraph, mentioning: why not `latest`, why an explicit patch version, and why `slim-bookworm` over Alpine for *this specific application*.

## Recap

A base image is a real, consequential dependency, not a throwaway first line - and "smallest possible" is not the same question as "most appropriate." Next: actually building the first image.
