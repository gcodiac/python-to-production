# Lesson 12 — Dependency Update Automation

**What you'll learn:** what `.github/dependabot.yml` actually does in this project, and why it proposes rather than merges.

## Goal

Read this project's Dependabot configuration and explain, for each of its three ecosystems, what kind of update it will propose.

## Why this matters in real DevOps/platform work

```text
automated update PR
      ↓
normal quality/security gates
      ↓
review
      ↓
merge
```

Dependency updates are exactly the kind of routine, easy-to-forget work automation is good at proposing - and exactly the kind of change that should never be trusted blindly. Dependabot's whole design reflects that split: it opens PRs, it doesn't merge them.

## This project's configuration

```bash
cat .github/dependabot.yml
```

Three ecosystems, each weekly:

* **`pip`** — this project's own `pyproject.toml`/locked dependencies (Lesson 06 of Stage 2's track).
* **`github-actions`** — the third-party Actions pinned throughout `pr-checks.yml`/`release.yml` (Lesson 11's supply-chain point, automated: these are dependencies too).
* **`docker`** — the base image pinned in the `Dockerfile` (Stage 2's base-image-choice lesson).

## Investigation steps

### 1. Confirm no auto-merge exists anywhere

```bash
grep -ri "automerge\|auto-merge" .github/dependabot.yml .github/workflows/*.yml
```

You should find nothing - every Dependabot PR still has to pass `pr-checks.yml` like any other change, and still needs a human review.

### 2. Understand what happens to a Dependabot PR concretely

A Dependabot PR targeting, say, a `fastapi` patch bump would trigger `pr-checks.yml` exactly like a human-authored PR - Ruff, pytest, Bandit, `pip-audit`, Hadolint, a real Docker build, and a real Trivy scan, all against the *proposed new version*.

## Questions for the learner

1. Why does automatically merging a `github-actions` ecosystem update carry a different risk than automatically merging a `pip` update, given both are "just a dependency bump"? (Reconnect to Lesson 11's action-pinning-as-supply-chain-dependency point.)
2. If Dependabot proposed bumping the pinned base image tag in the `Dockerfile` (e.g. `python:3.12.14-slim-bookworm` → a newer patch), would `pr-checks.yml`'s Trivy step have any chance of catching a *regression* introduced by that bump? What would it definitely catch, and what might it miss?
3. `open-pull-requests-limit: 5` is set for all three ecosystems. What problem does that guard against, specifically?

## Practical exercise

Design (don't implement) what a sensible review checklist for a Dependabot PR on this project would include, using this project's existing tools as the checklist items - you already know all of them from Stages 1 and 2, plus this stage's automation of them.

## Verification / checkpoint

You should be able to explain, for any one of the three configured ecosystems, exactly what file(s) Dependabot is watching and what update it would propose finding a new version.

## Recap

Dependency updates are proposed automatically and validated automatically - but never merged automatically. The same quality and security gates protecting a human's change protect a robot's. Next: what a controlled release actually looks like end to end, environments included.
