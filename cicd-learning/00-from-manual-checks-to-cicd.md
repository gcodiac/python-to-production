# Lesson 00 — From Manual Checks to CI/CD

**What you'll learn:** exactly what "automating" Stage 2's manual gate means, and doesn't mean.

## Goal

Understand the relationship between the commands you already know (Stage 2) and the CI/CD system this track builds - before looking at a single line of workflow YAML.

## Why this matters in real DevOps/platform work

> CI/CD will automate a process you already understand manually.

If that sentence isn't true for you yet, stop and go back through Stage 2 before continuing here. Everything in this track is a *trigger* for commands you've already run by hand: `pytest`, `ruff check app/`, `bandit -r app/`, `pip-audit`, `hadolint Dockerfile`, `docker build`, Trivy, Syft. None of the underlying work is new. What's new is *who* runs it (a GitHub-hosted machine, not you) and *when* (automatically, on every relevant change, not when you remember to).

## Concepts

* **CI (Continuous Integration)** — automatically validating every change (tests, lint, security checks) as it's proposed, so problems are caught before they're merged.
* **CD (Continuous Delivery/Deployment)** — automatically getting a validated change into a releasable (Delivery) or actually deployed (Deployment) state. This project practices Delivery: an automated, trustworthy artefact is produced and published, but nothing auto-deploys anywhere.
* **Pipeline** — the ordered sequence of automated steps a change goes through.
* **GitHub Actions** — the specific CI/CD platform this project uses, since the repository already lives on GitHub.

## Investigation steps

### 1. Look at the actual repository this stage works against

```bash
git remote -v
```

### 2. Confirm the branch structure this stage builds on

```bash
git log --oneline --graph --decorate --all -20
```

## Questions for the learner

1. Stage 2 ended with a `Makefile` target, `make check`, that ran the entire manual gate with one command. What does CI/CD add on top of that, that typing `make check` yourself does not give you?
2. If a teammate forgets to run `make check` before opening a pull request, what happens under Stage 2 alone? What happens once this track's automation exists?
3. "CI" and "CD" are often said together as one word. Based on the definitions above, could a project reasonably have CI without CD, or CD without CI? What would each look like?

## Practical exercise

Write down, from memory, the exact Stage 2 manual gate sequence (the one `make check` runs). You'll spend this whole track watching that same sequence get triggered by a `git push` instead of by your own hands - so this list should feel completely familiar by the end.

## Verification / checkpoint

You should be able to state, in one sentence, why this track calls itself "CI/CD" rather than just "CI" - given that it also publishes a release artefact, but never deploys one anywhere.

## Recap

CI/CD is not a new set of checks - it's the same checks from Stage 2, running automatically, consistently, on real infrastructure, triggered by real events. Next: what those triggering events actually are.
