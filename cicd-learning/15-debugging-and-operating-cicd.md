# Lesson 15 — Debugging and Operating CI/CD

**What you'll learn:** the real `gh run`-based debugging loop this project already used once (Lesson 02), generalised - plus this project's recommended, not-yet-applied branch protection settings.

## Goal

Be able to diagnose a failing GitHub Actions run using nothing but `gh`, and know exactly what branch protection this project recommends for when it's ready to enforce it.

## Why this matters in real DevOps/platform work

> If a REAL CI workflow fails due to your configuration: don't hide it. Observe failure → understand cause → fix configuration → commit → push → rerun.

This isn't advice for a hypothetical - it's literally what happened building this project's own pipeline (Lesson 02). This lesson generalises that exact loop into a repeatable debugging skill.

## The debugging loop, as commands

```bash
# 1. What's running or just finished?
gh run list --branch devops/03-cicd --limit 10

# 2. Which job/step failed?
gh run view <run-id>

# 3. What did it actually say?
gh run view <run-id> --log | grep -B5 -A20 "<failing step name>"

# 4. After a fix: push, then watch the new run
git push origin devops/03-cicd
gh run watch <new-run-id> --exit-status
```

## Investigation steps

### 1. Re-walk this project's real example

```bash
gh run view 34149340197        # the failing run
gh run view 34149482129        # the fixed run, immediately after
```

### 2. Confirm the fix commit is exactly what changed

```bash
git show 11773b0 --stat
```

One file, one line changed - the smallest fix that addressed the actual cause.

## Recommended branch protection (documented, not applied)

This project does not modify any branch protection or repository ruleset settings - those are repository *settings*, not files, and applying them isn't part of this exercise. Recommended configuration for `main` (and eventually `devops/0X-*` branches, once they're the active integration target) once this project moves toward real production use:

* Require a pull request before merging (no direct pushes).
* Require the `PR Checks` workflow's jobs to pass before merging.
* Require conversation resolution before merging.
* Require at least one approving review.
* Restrict who can push directly, even for administrators, on the protected branch.

Confirm the current (deliberately unprotected, for this training repository) state:

```bash
gh api repos/gcodiac/python-to-production/branches/main/protection 2>&1
```

## Questions for the learner

1. Why does this lesson recommend branch protection rather than just applying it via `gh api repos/.../branches/main/protection` right now?
2. If `main` had required-status-checks branch protection configured today, requiring `PR Checks` to pass, would that check the real, correct workflow? (Trick question - re-read Lesson 01: which branches does `pr-checks.yml`'s trigger actually cover?)
3. Suppose a workflow run gets stuck "in progress" far longer than expected - reconnect to `timeout-minutes` (set on every job in both workflows). What actually happens once that timeout is hit, and why is that better than a job running indefinitely?

## Practical exercise

Run the branch-protection check command from this lesson yourself, and record the honest, current answer. Then pick any one of the five recommended settings above and write, in your own words, the exact GitHub UI path to configure it (Settings → Branches → ...).

## Verification / checkpoint

You should be able to walk someone else through this project's real Lesson 02 failure using only `gh run view`/`gh run list`/`git show` commands, without needing this document open.

## Recap

Debugging CI/CD is the same evidence-gathering discipline as debugging anything else - read the actual log, find the actual cause, make the smallest fix that addresses it, verify. This project's own history is proof it works. Next: this stage's remaining gap before cloud deployment.
