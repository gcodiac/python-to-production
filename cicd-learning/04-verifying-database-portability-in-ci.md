# Lesson 04 — Verifying Database Portability in CI

**What you'll learn:** how to build a two-tier test strategy — fast tests on every push, slower high-fidelity tests against a real database — and why "it passed on SQLite" is not the same claim as "the artefact works on PostgreSQL".

## Goal

Understand the `postgres-integration` job in `pr-checks.yml` and the PostgreSQL smoke test in `release.yml`, and be able to explain why the second one is the stronger of the two.

## Why this matters in real DevOps/platform work

The application has supported two database backends since Stage 1, and developers have been able to run either locally since Stage 2. Neither of those facts survives contact with time on its own. Support that nobody exercises is support that quietly breaks — someone writes SQL that only SQLite tolerates, a schema default gets expressed in one dialect, a driver-specific option creeps into engine creation. Nothing fails, because nobody runs the other backend, until the day it is the only backend that matters.

CI is what converts "we support PostgreSQL" from a claim into a continuously verified property. That is the entire job of this lesson.

## Concepts

* **The testing pyramid, applied to databases** — many fast tests with a cheap stand-in, fewer slow tests against the real thing.
* **Service containers** — GitHub Actions can start a container alongside a job (`services:`) and wait for its health check before running any step.
* **Ephemeral credentials** — a password for a database that exists for ninety seconds, reachable only from one runner, is not a secret and must not be stored like one.
* **Source-level vs. artefact-level testing** — running `pytest` proves the *code* is portable. Running the *built image* against PostgreSQL proves the thing you are about to ship is.
* **Build once** — the integration test must run against the image that will be published, not a rebuild of it.

## The two tiers

```text
                    ┌──────────────────────────────────────┐
   every push  ───► │  pytest (SQLite)                     │  seconds
                    │  no services, no waiting             │
                    └──────────────────────────────────────┘
                                    │
                                    ▼
                    ┌──────────────────────────────────────┐
   every push  ───► │  pytest (PostgreSQL service)         │  ~1 minute
                    │  same test files, DATABASE_URL swap  │
                    └──────────────────────────────────────┘
                                    │
                                    ▼
                    ┌──────────────────────────────────────┐
   release     ───► │  BUILT IMAGE + real PostgreSQL       │  strongest
                    │  API write, verified with psql       │
                    └──────────────────────────────────────┘
```

## Investigation steps

### 1. Find the fast tier

```bash
grep -n -A4 "pytest (SQLite)" .github/workflows/pr-checks.yml
```

Note there is no `services:` block on that job, and nothing to wait for.

### 2. Find the service container

```bash
sed -n '/postgres-integration:/,/dockerfile-lint:/p' .github/workflows/pr-checks.yml
```

Look closely at three things: the pinned image tag, the `options:` health check, and the password.

### 3. Notice what the PostgreSQL job does *not* contain

There is no second copy of the test suite. The job runs `pytest` — the same files — with `DATABASE_URL` pointing somewhere else:

```bash
grep -n "setdefault" tests/test_notes.py
```

`os.environ.setdefault` is what makes this possible. If the tests had used plain assignment, they would force SQLite and silently ignore anything CI supplied.

### 4. Find the artefact-level test

```bash
grep -n -B4 -A4 "postgres-smoke-test" .github/workflows/*.yml
```

Both workflows run the same script a developer runs locally with `make postgres-test`, passing `NOTES_APP_IMAGE` so it targets the image CI just built.

## Questions for the learner

1. The PostgreSQL password appears in plain text in `pr-checks.yml`. Explain precisely why this is correct here, and describe a change to the workflow that would make it incorrect.
2. What would break if `tests/test_notes.py` used `os.environ["DATABASE_URL"] = ...` instead of `setdefault`? Would CI fail loudly, or pass while testing the wrong thing?
3. The service container declares a `--health-cmd`. What class of failure appears if you remove it, and why would it be intermittent rather than consistent?
4. `pytest` against a PostgreSQL service and the smoke test against the built image both "test PostgreSQL". Name something the second one catches that the first cannot.
5. The release workflow runs its PostgreSQL test *before* pushing to GHCR. Why is that ordering not negotiable?
6. Why does the release workflow not rebuild the image for the PostgreSQL test, even though rebuilding would be simpler to write?

## Expected observations

`quality-and-security` finishes in well under a minute with no service container. `postgres-integration` spends a few seconds waiting for `pg_isready` to pass, then runs the identical suite and reports the same number of passing tests. If the two ever disagree, that difference is a real portability bug and exactly what this job exists to surface.

In the release workflow, the PostgreSQL smoke test runs against the tag that is about to be pushed, and the digest published afterwards belongs to that same image. Nothing is rebuilt between testing and publishing.

## Parity is not identity

It is tempting to conclude from this lesson that everyone should just run PostgreSQL everywhere, and delete the SQLite path. That would be the wrong lesson.

> **Development and production should be similar enough to expose real integration problems. That is not the same as demanding every developer reproduce production exactly.**

The two-tier design is a deliberate trade:

| | SQLite tier | PostgreSQL tier |
|---|---|---|
| Feedback speed | seconds | tens of seconds |
| Setup required | none | a service container |
| Runs on a laptop offline | yes | needs a local server |
| Catches dialect bugs | no | yes |
| Frequency | every push, always | every push, in CI |

SQLite keeps the inner loop fast. PostgreSQL keeps the fidelity honest. CI is the place to pay the cost of the second one, because CI has no attention span to lose — a developer who has to wait forty seconds for every test run will start skipping tests, and that costs far more than a dialect bug.

## The progression this completes

```text
Stage 1   the source supports both backends
Stage 2   developers can run either one locally
Stage 3   CI proves both keep working, on every change      <- you are here
Stage 4   the cloud supplies managed PostgreSQL
```

By the time Stage 4 points the application at a managed database, PostgreSQL is not a new capability being introduced under deployment pressure. It is a backend this application has been running and testing on for two stages.

## Practical exercise

Break portability on purpose and watch the right job fail.

Add a deliberately SQLite-only statement to the application — for example, in `app/database.py`, execute raw SQL using `INSERT OR REPLACE`, which PostgreSQL does not understand. Push it on a branch and open a pull request against `devops/02-containerisation-supply-chain`.

Predict, before looking: which jobs go green and which go red? Then check `gh run view --log-failed` and see whether you were right. Revert afterwards.

## Verification / checkpoint

You should be able to state: which job runs which backend, why the CI database password is not a GitHub Secret, the one-line change in the test bootstrap that makes the second tier possible, and why testing the built image is a stronger claim than testing the source.

## Recap

CI now verifies both database backends on every change — the fast tier for speed, the service-container tier for fidelity, and an artefact-level test that proves the exact image being published works against a real PostgreSQL server. Database portability has stopped being a design intention and become a property that cannot silently regress.
