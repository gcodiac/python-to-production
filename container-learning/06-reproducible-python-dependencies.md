# Lesson 06 — Reproducible Python Dependencies

**What you'll learn:** why `fastapi>=0.115` in `pyproject.toml` doesn't guarantee you get the same dependencies tomorrow that you got today - and how this project locks them, matching commit `39399c9`.

## Goal

Understand the gap between a *declared* dependency and a *resolved* one, and inspect this project's `requirements.txt`/`requirements-dev.txt` lock files.

## Why this matters in real DevOps/platform work

"It worked when I built it last week" is a symptom of unlocked dependencies. `pyproject.toml`'s `dependencies = ["fastapi>=0.115", ...]` is a *constraint*, not a *decision* - it tells pip "anything 0.115 or newer is acceptable," and every fresh build re-resolves that constraint against whatever versions exist on PyPI *right now*. A build today and a build in three months, from the exact same Git commit, can legitimately install different dependency versions - which means a bug that only appears in a newer transitive dependency can show up in production without a single line of your own code changing.

## Concepts

* **Direct dependency** — something your code imports directly and you declared yourself (`fastapi`, `uvicorn`, `python-dotenv`).
* **Transitive dependency** — something a direct dependency needs, that you never declared (e.g. `starlette`, which FastAPI depends on; `click`, which uvicorn's CLI depends on).
* **Version constraint** — the range you wrote (`>=0.115`). Many different concrete versions satisfy it.
* **Resolved dependency** — the *one specific version* pip actually chose, at the moment it ran, out of everything satisfying every constraint in the whole dependency tree at once.
* **Lock file** — a file that pins every resolved dependency (direct and transitive) to one exact version, so the *same* resolution happens every time, regardless of what's newly published on PyPI in between.
* **`pip freeze` isn't a lock file** — `pip freeze` just dumps whatever happens to be installed in your current environment right now. It has no record of which packages were *direct* choices versus transitive fallout, no integrity hashes, and nothing stopping it from including packages that came from somewhere other than a clean resolution (leftover dev tools, an old install, anything). It's a snapshot of an environment, not a reproducible build input.

## Investigation steps

### 1. Look at the constraint-based source of truth

```bash
cat pyproject.toml
```

### 2. Look at what actually got resolved and locked

```bash
head -20 requirements.txt
wc -l requirements.txt requirements-dev.txt
```

### 3. See the tool that produced them

```bash
pip install pip-tools
pip-compile --generate-hashes --output-file=requirements.txt pyproject.toml
```

That's the exact command this project's lock file was generated with (pip-tools' `pip-compile`, chosen because this project already uses plain pip + `pyproject.toml` + setuptools - it extends that existing toolchain rather than replacing it with a different packaging ecosystem entirely).

### 4. Confirm hash-verified installation actually works

```bash
python3 -m venv /tmp/lock-check
source /tmp/lock-check/bin/activate
pip install --require-hashes -r requirements.txt
deactivate
rm -rf /tmp/lock-check
```

## Questions for the learner

1. `requirements.txt` has well over 100 lines for a project with 3 direct dependencies. What's making up the rest of it?
2. Why are there *two* lock files (`requirements.txt`, `requirements-dev.txt`) instead of one? What goes in each, and why does that split matter once you get to Lesson 07's Docker layer that installs dependencies?
3. `--require-hashes` makes `pip install` refuse to install anything whose downloaded file doesn't match the hash recorded in the lock file. What real attack does that protect against, specifically?
4. If a real CVE were published tomorrow against a transitive dependency this project happens to pull in, how would you find out which *direct* dependency pulled it in? (Look at the `# via ...` comments pip-compile writes into `requirements.txt`.)

## Expected observations

`requirements.txt` locks every direct *and* transitive dependency of the runtime dependency set to one exact version, with `--hash=sha256:...` entries per package - both `annotated-doc` (a transitive dependency of FastAPI you never explicitly asked for) and `fastapi` itself get exactly one resolved version, forever, until someone deliberately re-runs `pip-compile`. `requirements-dev.txt` is a separate lock covering the `dev` extra (`pytest`, `ruff`, `bandit`, plus everything `requirements.txt` already locks) - kept apart because the Docker image (Lesson 07) should only ever install the first one.

## Practical exercise

Re-run `pip-compile --generate-hashes --output-file=requirements.txt pyproject.toml` yourself right now, and diff the result against what's already committed. If nothing meaningfully changed, that's the lock file doing its job - stable across regenerations. If something *did* change, that's a real upstream release since this lesson was written, and now you know exactly how to notice that.

## Verification / checkpoint

You should be able to explain the difference between "I declared `fastapi>=0.115`" and "I locked `fastapi==0.115.x`, plus every one of its transitive dependencies, with hashes" - and why only the second one is a legitimate input to a reproducible container build.

## Recap

Building the same Git commit twice should produce a predictably equivalent dependency set - that's what `requirements.txt`/`requirements-dev.txt` guarantee, and `pyproject.toml` alone does not. With that in place, the Dockerfile itself is next to improve.
