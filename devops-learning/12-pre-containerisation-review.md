# Lesson 12 — Pre-Containerisation Review

**What you'll learn:** how to run a structured "handover audit" against an application, pulling together everything from Lessons 00–11 into one honest checklist.

## Goal

Produce a completed, honest review of this application's current state — what's genuinely ready, and what (if anything) you're consciously choosing to leave for later — the way you'd hand off a status report to a team lead before starting containerisation work.

## Why this matters in real DevOps/platform work

Real teams use checklists like this constantly — before a migration, before containerising a legacy service, before an on-call handover. The value isn't ticking boxes; it's forcing yourself to actually verify each claim rather than assume it. A checklist item you can't honestly tick is far more useful to know about now than after you've built a `Dockerfile` around an assumption that turned out to be wrong.

## The checklist

Go through each item below **by actually re-running the relevant command**, not from memory. For each one, mark it ✅ Done, ⚠️ Partially done (explain what's left), or ❌ Not done (explain why, if that was a deliberate choice).

```text
[ ] I can describe what this application does and how it's structured, unaided.
[ ] I can run the application from a clean environment using only the README.
[ ] I know exactly what Python version and dependencies (runtime vs. dev-only) it needs.
[ ] The full test suite passes.
[ ] I have run a linter (ruff) against the code and triaged every finding.
[ ] I have run a security scanner (bandit) against the code and triaged every finding.
[ ] I have a complete inventory of hard-coded configuration values, with file:line for each.
[ ] Configuration is read from environment variables, with sensible local fallbacks.
[ ] A working .env file exists locally and is excluded by .gitignore.
[ ] A committed .env.example documents every required variable, with no real secrets in it.
[ ] I understand why the same set of variables should have different values per environment.
[ ] I know where this app's logs go (stdout/stderr) and what currently controls their verbosity.
[ ] I know what /health does and does not currently verify.
[ ] I have personally observed what happens to this app when its database is unavailable.
[ ] I know what port/host this app listens on, and by which of its (possibly inconsistent) code paths.
```

## Commands to run (re-verify, don't assume)

```bash
source .venv/bin/activate
pytest -v
ruff check app/
bandit -r app/
grep -rn "TRAINING-ISSUE" app/
cat .env.example 2>/dev/null || echo "no .env.example yet"
git status
```

## Questions for the learner

1. Which checklist items can you tick with full confidence, backed by a command you just ran?
2. Which items are only partially done? What specifically is left?
3. Of the original `TRAINING-ISSUE` items you found across Lessons 05–07, which have you actually resolved by this point, and which are you consciously leaving as-is? (It's fine to leave some — this track asked you to *externalise configuration*, not necessarily rewrite every code smell. Be explicit about the difference between "I fixed this" and "I understood this and chose not to touch it yet.")
4. If you handed this checklist, as-is, to a colleague who was about to write a `Dockerfile` for this app, is there anything on it that would make you say "wait, don't start yet"?

## Practical exercise

Write your checklist out as an actual file (`devops-learning/my-review-notes.md`, or wherever you keep your own working notes — this is deliberately *not* a file this course ships for you, since it needs to reflect your own honest state, not a pre-filled answer). Include, for every ⚠️ or ❌ item, one sentence on what specifically remains.

## Verification / checkpoint

You should have a checklist with **evidence** behind every ✅ — a command you ran, an output you read — not a checklist filled in from memory. If you're not sure whether an item is really done, that's your signal to go re-run the relevant lesson's commands rather than guess.

## Recap

You've conducted a full, structured review of an inherited application's readiness, grounded in commands you actually ran rather than assumptions — exactly the kind of audit a platform team performs before taking on responsibility for a new service. One lesson remains: understanding what all of this groundwork was actually *for*.
