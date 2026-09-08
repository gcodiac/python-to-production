# Lesson 08 — Build Once, Promote Many

**What you'll learn:** the single most important design decision in `release.yml`, and how to verify it's actually true rather than just claimed.

## Goal

Prove, from the workflow file itself, that the image this project scans, smoke-tests, and publishes is genuinely the *same* image throughout - never rebuilt.

## Why this matters in real DevOps/platform work

```text
WRONG

build staging
     ↓
later rebuild production
```

If "staging" and "production" are two separate builds - even from the identical Git commit - you have no guarantee they're actually identical. A different dependency resolution at a slightly different moment, a base-image patch published in between, a non-deterministic build step: any of these can make "rebuild production" produce something subtly different from what was actually tested.

```text
BETTER

build once
    ↓
test
    ↓
scan
    ↓
publish
    ↓
capture digest
    ↓
promote same digest
```

> The production artefact should be the artefact that was tested. Not merely another image built from the same Git commit.

## Investigation steps

### 1. Count the build steps in `release.yml`

```bash
grep -n "docker/build-push-action\|docker buildx build" .github/workflows/release.yml
```

There should be exactly **one**.

### 2. Trace what happens to that one build

```bash
sed -n '/Build release image/,/Publish to GHCR/p' .github/workflows/release.yml
```

Notice the sequence: build with `load: true` (into the runner's local Docker daemon, not pushed) → Trivy scans that exact local image reference → the smoke test runs that exact local image reference → *only then* does `docker push` publish that exact same image.

### 3. Confirm this in the real run

```bash
gh run view 34150267799 --log | grep -E "Build release image|Scan the built image|Smoke test|Publish to GHCR"
```

Same job, same steps, same image reference throughout - no second build step anywhere in between.

## Questions for the learner

1. If Trivy's scan step had found a blocking HIGH/CRITICAL vulnerability, what would have happened to the `docker push` step later in the same job? Would a *different*, "fixed" image have been quietly built and pushed instead?
2. Why does `docker/build-push-action` use `load: true` and `push: false` here, rather than just `push: true` immediately? What would "build once" actually mean if the image were pushed *before* being scanned?
3. The image is tagged `sha-<commit>` before it's ever scanned, and that exact tag is what eventually gets pushed. Why does tagging it *before* scanning (rather than choosing a tag only at publish time) matter for keeping "the thing we scanned" and "the thing we published" unambiguously the same object?

## Practical exercise

Imagine (don't implement) a hypothetical `staging` and `production` deployment step added to a future stage. Using this lesson's diagram, write one sentence describing what each deployment step should actually *do*: pull and run a specific pre-existing digest, or run `docker build` again? Justify your answer using this lesson's core principle.

## Verification / checkpoint

You should be able to point to the exact single `docker/build-push-action` step in `release.yml` and trace every subsequent step's image reference back to that one build, with no second build appearing anywhere.

## Recap

This project's release workflow doesn't just claim "build once, promote many" - the workflow's own structure makes it true, and reading it any real evidence of that structure is a genuine trust signal a git history diff would never show and a rebuild-based pipeline could never provide.
