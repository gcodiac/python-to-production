# Lesson 24 — Building a Manual Release Quality Gate

**What you'll learn:** assembling every check from this entire track into one deliberate sequence, run by hand, that decides whether an image is a release candidate.

## Goal

Run this project's complete release gate, understand every step in it, and internalise the core lesson before Stage 3 automates any of it.

## Why this matters in real DevOps/platform work

> CI/CD will later automate a process you already understand manually.

If you don't already know precisely what "passing CI" is supposed to mean, automating it just means you now fail to understand your own pipeline faster. This lesson is the whole reason this track insisted on manual commands throughout, instead of jumping straight to a `Makefile` or a pipeline definition.

## The complete gate

```text
SOURCE
  |
  +-- pytest ---------------- PASS
  |
  +-- Ruff ------------------ PASS
  |
  +-- Bandit ---------------- PASS/REVIEW
  |
  +-- pip-audit ------------- PASS/REVIEW
  |
  v
DOCKER BUILD
  |
  +-- Hadolint -------------- PASS/REVIEW
  |
  +-- image builds ---------- PASS
  |
  +-- smoke tests ----------- PASS
  |
  +-- persistence test ------ PASS
  |
  +-- non-root check -------- PASS
  |
  +-- Trivy ----------------- PASS/REVIEW
  |
  +-- secret scan ----------- PASS
  |
  +-- SBOM generated -------- YES
  |
  +-- Grype ----------------- PASS/REVIEW
  |
  v
RELEASE CANDIDATE
```

## Running it, step by step

```bash
pytest
ruff check app/
bandit -r app/
pip-audit -r requirements.txt
pip-audit -r requirements-dev.txt
hadolint Dockerfile
docker build --build-arg GIT_REVISION=$(git rev-parse --short HEAD) -t notes-app:local .
./scripts/container-smoke-test.sh
trivy fs --scanners vuln,secret,misconfig .
trivy image notes-app:local
syft dir:. --source-name notes-app --source-version 0.1.0 \
    -o cyclonedx-json=reports/sbom.cdx.json
grype sbom:reports/sbom.cdx.json
```

Or, via the `Makefile` this project provides once you already understand every one of those commands individually:

```bash
make check
```

## Investigation steps

### 1. Read the Makefile's `check` target

```bash
grep -A2 "^check:" Makefile
```

Notice it's a plain list of the same targets you'd run by hand, in the same order - `make check` is a convenience, not a black box.

### 2. Run each piece, and record PASS/REVIEW/FAIL honestly

Use `SECURITY.md`'s recorded results as your reference for what this project's tools currently report.

## Questions for the learner

1. Several steps in the diagram are marked `PASS/REVIEW`, not just `PASS`, while `pytest`, `image builds`, and `secret scan` are marked plain `PASS`. What's the actual difference - why can't Bandit/Trivy/Grype results always collapse to a simple pass/fail the way a test suite can?
2. `container-test`, `scan`, and `sbom` all depend on `build` having already produced a real image. What would happen if you ran `make check` on a machine without Docker installed at all? Which specific targets would fail, and which would still succeed?
3. Why does this lesson - and this whole track - insist on you running every one of these commands by hand at least once, *before* relying on `make check`?

## Practical exercise

Run the complete gate yourself, top to bottom, exactly as listed above (or via `make check` if you have `make` installed). For any step that isn't a clean PASS, apply Lesson 16's triage workflow and record your decision, the same way `SECURITY.md` already does for this project's current (clean) results.

## Verification / checkpoint

You should have a complete, honest run of every step in this gate, with a real result recorded for each - not an assumption that everything from earlier lessons still holds.

## Recap

You now have, by hand, the exact sequence of checks that decides whether a container image is a release candidate - the same sequence Stage 3 will wire into an automated pipeline, changing nothing about *what* is checked, only *who* (or what) runs it. Last lesson: what that automation will actually look like, and why it isn't built yet.
