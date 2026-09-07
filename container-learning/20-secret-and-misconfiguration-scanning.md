# Lesson 20 — Secret and Misconfiguration Scanning

**What you'll learn:** the single most important, most-forgotten fact about container layers and secrets - and how to investigate whether this project is exposed.

## Goal

Understand why "I removed the secret in a later line of the Dockerfile" does not mean "the secret is gone," and confirm this project never creates that problem in the first place.

## Why this matters in real DevOps/platform work

This is one of the most common real incidents in container security, and one of the easiest to prevent entirely by just never doing the thing in the first place - which is exactly this project's approach (Lesson 09).

## The critical lesson

> Deleting a secret in a later Docker layer does not necessarily remove it from previous layers.

Each Dockerfile instruction that touches the filesystem creates a new, immutable layer (Lesson 02). If one layer writes a secret to a file, and a *later* layer deletes that file, the file is gone from the final merged filesystem view - but the layer that originally contained it still exists inside the image, and anyone who pulls the image can extract and inspect every layer individually, including the "deleted" one.

## Where secrets could sneak in (and where to check)

* **`.env` entering the build context** — checked by `.dockerignore` (Lesson 05); confirm: `git check-ignore -v .env 2>/dev/null; grep -n '^\.env' .dockerignore`.
* **`.env` entering the image itself** — only possible if a `COPY` instruction explicitly grabbed it. Confirm: `grep -n "COPY" Dockerfile`.
* **A secret baked in via `ARG`** — appears in `docker history` for any image built with BuildKit's legacy (non-secret-mount) `ARG` handling. Confirm: `grep -n "^ARG" Dockerfile` and check what each one is actually used for (this project's only `ARG`, `GIT_REVISION`, is non-sensitive build metadata - Lesson 23).
* **A secret baked in via `ENV`** — permanently part of every downstream layer, visible in `docker inspect`. Confirm: `grep -n "^ENV" Dockerfile` and check none of Stage 1's six config values (especially `APP_SECRET`) appear.

## Investigation steps

### 1. Confirm none of the above apply to this project

```bash
grep -n "COPY\|^ARG\|^ENV" Dockerfile
```

### 2. Trivy's secret scanner, across the source tree

```bash
trivy fs --scanners secret .
```

**Result (most recent run): no secrets found.**

### 3. Once you have Docker: scan the actual built image too

```bash
docker build -t notes-app:local .
trivy image --scanners secret notes-app:local
```

Source-tree secret scanning (which this environment could run) and image secret scanning (which needs Docker - see Lesson 19's honesty note) are checking different things: the first is "did we commit a secret," the second is "did a secret end up in a layer regardless of how."

## Questions for the learner

1. Walk through this project's `Dockerfile` line by line and confirm, yourself, that no secret-shaped value is ever written by any instruction. What specifically would you look for if you *hadn't* already been told the answer?
2. Suppose a teammate "fixed" an accidental secret leak by adding a new Dockerfile line, `RUN rm /app/secret.txt`, right after the line that created it. Does this actually fix the problem? What would you need to do instead (hint: it usually means rebuilding the image without that layer ever existing, not adding a cleanup layer after it)?
3. Where would you look, specifically, to *prove* a "deleted" file is still recoverable from an image's layer history? (`docker save notes-app:local -o image.tar` followed by extracting and inspecting the tarball's layer `.tar` files is the hands-on way - conceptually, that's what `trivy image --scanners secret` and tools like Gitleaks automate.)

## A note on Gitleaks

Gitleaks is a well-known tool specifically for scanning **git history** (not container images) for accidentally committed secrets. It's mentioned here conceptually because the underlying lesson - "history remembers what you think you removed" - is identical whether the history in question is Docker layers or git commits. This project doesn't add Gitleaks as a second, redundant tool: Trivy's secret scanner already covers the working tree, and this project's git history (Stage 1's `TRAINING-ISSUE` fake secret, deliberately never a real one) was already handled in Stage 1's own review.

## Practical exercise

Confirm for yourself that `.env` (if you've created one locally, per Stage 1/Lesson 12) is genuinely excluded from what git tracks and what Docker's build context receives:

```bash
git status --short   # .env should not appear as trackable
git check-ignore -v .env
```

## Verification / checkpoint

You should be able to explain, without looking it up, why a `RUN rm secret-file` line added after the line that created it does not actually remove the secret from the image - and confirm, by reading this project's `Dockerfile`, that it never creates the problem in the first place.

## Recap

The safest way to handle "secrets in layers" is never creating them - which is exactly what Lesson 09's runtime-only configuration already guarantees here, confirmed now by both manual review and Trivy's secret scanner. Next: making the runtime itself harder to abuse, even if something does go wrong.
