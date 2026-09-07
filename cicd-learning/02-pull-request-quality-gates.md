# Lesson 02 — Pull Request Quality Gates

**What you'll learn:** the `quality-and-security` job in `pr-checks.yml` - and a real failure it caught on this exact repository, on its very first run.

## Goal

Understand every step of the first job in `pr-checks.yml`, and walk through a genuine CI failure this project hit, end to end: observed, understood, fixed, verified.

## Why this matters in real DevOps/platform work

This lesson isn't hypothetical. The story below is exactly what happened building this project's real CI, on GitHub Actions, against this real repository - including the failure.

## The job

```bash
sed -n '/quality-and-security:/,/dockerfile-lint:/p' .github/workflows/pr-checks.yml
```

Five steps, in this order, deliberately: checkout, install (with `pip` caching), Ruff, `pytest`, Bandit, `pip-audit`. Cheapest and fastest first - see Lesson 01's fail-fast reasoning.

## A real failure, and its fix

The very first run of this workflow (commit `cb20926`, run `34149340197`) failed - not on a mistake in the workflow's *logic*, but on an assumption about a tool's *default behaviour*:

```text
X Bandit (source security patterns)
##[error]Process completed with exit code 1.
```

The actual finding Bandit reported was the exact same low-severity, already-reviewed finding documented in `SECURITY.md` since Stage 2 - a dev-only placeholder secret in `app/config.py` that the code guarantees is unreachable in production. Locally, running `bandit -r app/` and reading its output by eye, this had never been a problem - the finding was there, but nobody had checked bandit's *exit code* specifically.

**The cause:** Bandit exits non-zero if it finds *any* issue at all, regardless of severity, unless you explicitly tell it otherwise.

**The fix** (commit `11773b0`):

```bash
git show 11773b0
```

```diff
- run: bandit -r app/
+ run: bandit -r app/ --severity-level medium
```

This matches the exact "block medium+, document/report lower severities" policy this project already applied to Trivy - now made explicit and consistent for Bandit too.

**Verification:** the very next run (`34149482129`) passed cleanly - all three jobs, including the real Docker build and Trivy scan.

## Investigation steps

### 1. See both runs yourself

```bash
gh run list --branch devops/03-cicd --limit 10
```

### 2. Read the actual failing log

```bash
gh run view 34149340197 --log | grep -A5 "hardcoded_password_string"
```

## Questions for the learner

1. Why did this exact same Bandit finding never fail anything *locally*, across all of Stage 2's verification, but immediately failed in CI on the first real run?
2. The fix adds a severity threshold rather than suppressing the specific finding with `# nosec`. Reconnect this to Stage 2's own stated reasoning in `SECURITY.md` for *why* it avoided `# nosec` there - does the CI fix honour or contradict that reasoning?
3. If this project had a genuine HIGH-severity Bandit finding tomorrow, would `--severity-level medium` still catch it and fail the build? Confirm your answer by reading Bandit's own `--severity-level` documentation (`bandit --help`).

## Practical exercise

Reproduce the original failure yourself, safely, without touching the real workflow: run `bandit -r app/` (no severity flag) locally and check `echo $?` - confirm it's `1`, exactly what CI saw. Then run `bandit -r app/ --severity-level medium` and confirm `echo $?` is `0`.

## Verification / checkpoint

You should be able to explain, using this project's actual run history (not a hypothetical), the full loop: observe failure → understand cause → fix configuration → commit → push → rerun → verify green.

## Recap

A genuine, real CI failure - caught, understood, and fixed in one commit - is more valuable to have watched than a workflow that happened to pass on the first try. Next: the two other checks in this same job, from a security angle specifically.
