# Lesson 05 — Static Code Analysis

**What you'll learn:** the difference between linting, formatting, and maintainability analysis; how to run `pytest` and `ruff` against this codebase; and how to confirm a finding is a deliberately planted training issue.

## Goal

Run the existing test suite, then run a linter against the application code, and produce a triaged list of every finding it reports.

## Why this matters in real DevOps/platform work

Static analysis is one of the cheapest ways to catch real problems before they reach production — it runs in seconds, needs no running environment, and catches whole categories of bugs and maintainability issues automatically. Most CI/CD pipelines you'll build or maintain run these checks on every single commit, long before any deployment step. Knowing what each *category* of tool actually checks — and what it doesn't — is what lets you configure a pipeline sensibly instead of just bolting every tool onto it and hoping.

## Concepts

Static analysis is not one thing — it's several different concerns, often handled by different tools:

| Category | Question it answers | Example tool |
|---|---|---|
| **Testing** | Does the code behave correctly? | `pytest` |
| **Linting** | Does the code follow language rules/conventions and avoid obvious bugs (unused imports, undefined names)? | `ruff` |
| **Formatting** | Is the code laid out consistently (whitespace, quotes, line length)? | `ruff format`, `black` |
| **Maintainability / code smells** | Is the code needlessly complex, duplicated, or hard to change safely? | SonarQube/SonarCloud |
| **Security scanning** | Does the code contain known-risky patterns (covered in Lesson 06)? | `bandit` |

This lesson focuses on testing, linting, and maintainability. Security scanning gets its own lesson next, because it deserves a different mindset.

## Investigation steps

### 1. Run the existing tests first

Before analysing code quality, confirm the application is actually *correct* according to its own test suite:

```bash
source .venv/bin/activate
pytest -v
```

### 2. Run the linter

```bash
ruff check app/
```

### 3. Read the output carefully

Ruff groups findings by rule code (e.g. `F401`, `BLE001`). For each finding it reports:

* the rule code and a short description
* the file and line number
* often, a suggested fix

### 4. Cross-reference against the intentional training markers

This codebase has a small number of **deliberately planted** issues for you to find, each marked with a comment containing `TRAINING-ISSUE`. Now — and only now, after you've actually run a tool and read its output — check which of the issues you found were "real," intended problems:

```bash
grep -rn "TRAINING-ISSUE" app/
```

## Questions for the learner

1. How many findings did `ruff check app/` report? For each one, what category of problem is it (unused code, error-prone pattern, style)?
2. Cross-reference your `ruff` findings against the `TRAINING-ISSUE` list. Which training issues did `ruff` catch automatically? Which ones did it *not* catch?
3. Look at the ones `ruff` missed. Why do you think a simple linter wouldn't catch things like "this logic is duplicated in three places" or "this number should be a named constant"? What kind of tool is better suited to catching those?
4. Open `app/main.py` and read the `_resolve_sort_order` function. Would you say it's overly complex for what it does? Ruff's default rule set doesn't flag this by name — a tool that measures **cyclomatic** or **cognitive complexity** (which SonarQube/SonarCloud does) would.

## Commands to run

```bash
pytest -v
ruff check app/
grep -rn "TRAINING-ISSUE" app/
```

## Expected observations

All 5 tests pass. `ruff check app/` reports a small number of findings — an unused import, and an overly broad `except Exception: pass` block (flagged under more than one rule code). Both of those correspond to `TRAINING-ISSUE` comments. Several *other* `TRAINING-ISSUE` markers in the file — duplicated code, a duplicated string literal, a magic number, poor naming, an unnecessary complex function, an unnecessary variable — are **not** reported by `ruff check` with its default configuration. That's expected and important: a fast linter is tuned to catch clear-cut, mechanical problems, not to judge code structure or duplication. Tools like SonarQube/SonarCloud are built specifically to also score **duplication**, **cognitive complexity**, and **maintainability** — categories a linter alone won't cover. (You don't need to set up a real SonarCloud project for this exercise — understanding *what category of tool you'd reach for* is the point.)

## Practical exercise

Build a small table in your notes with one row per `TRAINING-ISSUE` you found in `app/`, with three columns: **the issue**, **file:line**, and **caught by `ruff`? (yes/no)**. You should end up with more "no" rows than "yes" rows — and that's the lesson, not a failure on your part.

## Verification / checkpoint

You should have all 5 tests passing, a `ruff check` output you can explain finding-by-finding, and a table showing which training issues a linter alone would and wouldn't have caught for you.

## Recap

You've distinguished testing, linting, formatting, and maintainability analysis, run real tooling against real (intentionally imperfect) code, and confirmed for yourself which categories of problems each tool actually catches. Next, you'll run a security-focused scan over the same code — a different lens entirely.
