# Lesson 01 — CI/CD and Pipeline Triggers

**What you'll learn:** what actually causes a GitHub Actions workflow to run, and why this project's two workflows use deliberately different triggers.

## Goal

Read this project's `.github/workflows/pr-checks.yml` and `.github/workflows/release.yml`, and explain exactly what event starts each one.

## Why this matters in real DevOps/platform work

Choosing the wrong trigger is one of the most common, most consequential CI/CD mistakes: a "release" workflow that fires on every push can publish a broken image to real infrastructure before anyone reviewed anything; a "validation" workflow that never fires on pull requests provides no protection at all.

## Concepts

* **`on:`** — the block at the top of a workflow file declaring what event(s) start it.
* **`pull_request`** — fires when a PR is opened or updated. This project's `pr-checks.yml` uses this, scoped to PRs targeting `devops/02-containerisation-supply-chain` or `main`.
* **`workflow_dispatch`** — a manual "run this now" button/API call, with optional typed inputs. This project's `release.yml` uses this as its primary, intended trigger.
* **`push` with `tags:`** — fires when a matching tag is pushed. This project's `release.yml` *also* has a temporary `stage3-test-*` tag trigger - see this lesson's practical exercise for why.

## Investigation steps

### 1. Read both triggers side by side

```bash
sed -n '/^on:/,/^permissions:/p' .github/workflows/pr-checks.yml
sed -n '/^on:/,/^permissions:/p' .github/workflows/release.yml
```

### 2. See real trigger events on this repository

```bash
gh run list --limit 10
```

Look at the "EVENT" column - `pull_request` runs versus `push` (tag) runs.

## Questions for the learner

1. `pr-checks.yml` restricts its `pull_request` trigger to two specific `branches:`. What would happen, functionally, if that restriction were removed - which additional PRs would start triggering it?
2. `release.yml`'s primary trigger is `workflow_dispatch` - a human (or an authorized API call) has to actively choose to run it. Why does that matter for a *release*, specifically, in a way it might not matter as much for `pr-checks.yml`?
3. Read this workflow's comment about why the `stage3-test-*` tag trigger exists at all. What real, specific GitHub platform constraint made `workflow_dispatch` alone insufficient for actually exercising this workflow while it lives only on a non-default branch?

## Practical exercise

Run:

```bash
git tag -l "stage3-test-*"
```

and read the comment directly above the `on:` block in `release.yml`. This is a genuine, encountered limitation, not a hypothetical: GitHub only allows `workflow_dispatch` to be triggered once a workflow file exists on the repository's *default* branch. Since merging `devops/03-cicd` into `main` is explicitly out of scope for this stage, a temporary tag trigger was the honest way to actually run this workflow for real rather than merely writing YAML that was never executed.

## Verification / checkpoint

You should be able to point to the exact line in each workflow file that determines when it runs, and explain why `release.yml`'s trigger is deliberately more restrictive/deliberate than `pr-checks.yml`'s.

## Recap

Triggers decide who can start a workflow and when - and getting that choice right is a real security and safety boundary, not just wiring. Next: what `pr-checks.yml` actually validates, step by step.
