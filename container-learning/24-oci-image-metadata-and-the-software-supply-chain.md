# Lesson 24 — OCI Image Metadata and the Software Supply Chain

**What you'll learn:** the OCI labels this project's `Dockerfile` sets, and the broader "software supply chain" vocabulary they're a small first piece of - matching commit `5f7e402`.

## Goal

Read and understand this project's image metadata, and be able to place this project's actual dependency chain into the standard supply-chain vocabulary.

## Why this matters in real DevOps/platform work

An image with no metadata is a mystery to anyone who receives it later - what built this, from what commit, what is it even for? OCI labels are a small, standard, cheap way to answer that. And this project's dependency chain - source, Python packages, Python runtime, Linux base image, the build process itself - is a real software supply chain, with real, well-known risks, even at this small a scale.

## OCI image metadata

```bash
grep -A5 "^LABEL" Dockerfile
```

* `org.opencontainers.image.title`, `.description`, `.version` — stable, human-readable identity, hardcoded because they rarely change and already exist as source-controlled facts (`pyproject.toml`'s own `name`/`description`/`version`).
* `org.opencontainers.image.revision` — the exact Git commit this image was built from. Deliberately **not** hardcoded - it's supplied as a build `ARG` (`--build-arg GIT_REVISION=$(git rev-parse --short HEAD)`), because it's only meaningful as of *when the build happened*, not something you'd want baked as a static value that goes stale the moment you commit again.
* **No `org.opencontainers.image.source`** — that label is meant to point at a real, public repository URL. This project doesn't have one to publish yet; inventing a fake one would be worse than omitting the label.

## Investigation steps

### 1. Confirm the labels, once built

```bash
docker build --build-arg GIT_REVISION=$(git rev-parse --short HEAD) -t notes-app:local .
docker inspect --format='{{json .Config.Labels}}' notes-app:local | python3 -m json.tool
```

### 2. Confirm the revision label actually matches your current commit

```bash
git rev-parse --short HEAD
```

## The software supply chain, for this project specifically

```text
our source (this git repository)
   +
Python dependencies (fastapi, uvicorn, python-dotenv, and everything they pull in transitively)
   +
Python runtime (CPython 3.12.14)
   +
Linux base image (Debian bookworm, slim variant)
   +
build process (this Dockerfile, run through Docker's builder)
   =
software supply chain
```

Every layer of that stack is something you're implicitly trusting the moment you build and run this image - and every layer is a potential compromise point, in principle, in a widely-publicized real-world sense (compromised upstream packages, typosquatted PyPI names, compromised base images).

## Concepts, introduced here conceptually only

* **Provenance** — verifiable evidence of *how* an artefact was built (from what source, by what process) - not yet implemented in this project.
* **Attestations** — signed statements about an artefact (e.g. "this image was built by this CI pipeline from this commit, and passed these checks") - not yet implemented.
* **Image signing** — cryptographically signing an image so consumers can verify it hasn't been tampered with since it was built - not yet implemented.

These three are explicitly **Stage 3 material** (CI/CD), not this branch's job - see `25-building-a-manual-release-quality-gate.md` and `26-ready-for-cicd.md`.

## Questions for the learner

1. Why does `GIT_REVISION` need to be a build `ARG` rather than a hardcoded `LABEL` value the way `.version` is?
2. Name one thing, specifically, that an SBOM (Lesson 18) gives you that a Git commit hash alone does not, for answering "what's actually in this image."
3. Provenance and image signing both require *automation* to be trustworthy at scale (a human manually signing images doesn't scale, and can't prove *how* something was built the way an automated, auditable pipeline can). Why does that naturally push those two specific concepts into "Stage 3: CI/CD" rather than this manual stage?

## Practical exercise

Build the image twice, with two different (fake, for this exercise) `GIT_REVISION` values, and confirm via `docker inspect` that the label actually changes between the two builds, proving it's genuinely dynamic rather than accidentally cached/hardcoded.

## Verification / checkpoint

You should be able to name this project's full supply chain (the five-layer stack above) from memory, and explain why signing/provenance/attestations are deliberately not implemented yet, rather than just "missing."

## Recap

Metadata turns an anonymous image into one anyone (including future you) can trace back to exactly what built it - and this project's supply chain, while small, is real and worth naming precisely. Next: assembling everything from this entire track into one manual release quality gate.
