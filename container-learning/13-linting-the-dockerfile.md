# Lesson 13 — Linting the Dockerfile

**What you'll learn:** running Hadolint against this project's `Dockerfile`, and an important, honest limitation of what it actually catches.

## Goal

Install and run Hadolint, understand its one real finding in this project's history, and be able to say precisely what categories of problems it does *not* catch.

## Why this matters in real DevOps/platform work

```text
Python source has linting (Ruff, Stage 1)
Dockerfiles should have linting too
```

Dockerfiles are code. They have well-known antipatterns, just like Python does, and a linter that knows those patterns catches mistakes before review, exactly the way Ruff does for `app/`.

## Installing Hadolint

Hadolint ships as a single static binary - no package manager integration required:

```bash
curl -fsSL -o ~/.local/bin/hadolint \
  https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64
chmod +x ~/.local/bin/hadolint
hadolint --version
```

## Investigation steps

### 1. Run it against the current Dockerfile

```bash
hadolint Dockerfile
```

### 2. See the one real finding this project actually hit

While adding the non-root user in commit `e53dc6e`, the first attempt used `USER appuser` (the username). Hadolint flagged it:

```text
Dockerfile:59 DL3066 info: Non-numeric user-id may not be resolvable by host system
```

The fix, in the same commit, switched to `USER 1000:1000` - the numeric form.

## Questions for the learner

1. Why would a *name* like `appuser` fail to resolve in some minimal images, when a numeric UID never has that problem? (Think about what `/etc/passwd` is, and whether every possible base image guarantees one exists and is readable.)
2. Run `hadolint Dockerfile` against this project's naive first version too:
   ```bash
   git show 3aa0b47:Dockerfile > /tmp/naive.Dockerfile
   hadolint /tmp/naive.Dockerfile
   ```
   That version runs as root, has no dependency-layer caching, and copies everything into the image. Does Hadolint flag any of that? What does the (lack of) output tell you about what a Dockerfile linter's default rules actually check versus what a full architectural review checks?
3. Where have you seen this exact "a linter catches syntax-level mistakes, not architectural ones" distinction before in this project? (Stage 1's Ruff-vs-SonarQube lesson made precisely this point about Python code.)

## Expected observations

Hadolint's default ruleset is genuinely useful (missing version pins on `apt-get install`, `ADD` where `COPY` was meant, this project's own `DL3066` finding) but has no rule for "you should run as non-root" or "you should order instructions for cache efficiency" - those are judgement calls a linter with a fixed rule set doesn't attempt to make.

## Practical exercise

Run `hadolint --format json Dockerfile` and note the output is empty/clean for the current (fixed) `Dockerfile`. Then deliberately introduce one classic mistake - add a line `RUN apt-get update && apt-get install -y curl` (no version pin, and this project doesn't even need curl - see Lesson 11) to a scratch copy of the Dockerfile, and see what Hadolint says about it. Remove the line afterwards; it was only for this exercise.

## Verification / checkpoint

You should be able to run `hadolint Dockerfile` yourself, get a clean result, and separately name at least two real problems (root user, layer caching) that a *previous* version of this Dockerfile had, that Hadolint's default rules never flagged.

## Recap

Hadolint is real, useful, cheap linting for Dockerfiles - and, like Ruff before it, it catches one category of mistake while leaving architectural review to a human (or a broader tool). Next: a different category entirely - are the *Python dependencies themselves* known to be vulnerable?
