# Lesson 07 — Improving the Dockerfile

**What you'll learn:** three real improvements this project's Dockerfile went through - caching/layering, a genuine packaging bug found along the way, and a multi-stage build - matching commits `2e40382`, `c48ff8d`, and `625865e`.

## Goal

Understand exactly what changed between the naive Dockerfile from Lesson 04 and the multi-stage one at this point in history, and why each change earns its place.

## Why this matters in real DevOps/platform work

This is where "the image builds" and "the image build is actually good engineering" start to diverge. Every change here is something you'll be expected to recognise (and fix) in a code review of someone else's Dockerfile.

## Change 1: caching and layering, plus pinning the base image (`2e40382`)

```bash
git show 2e40382 -- Dockerfile
```

Two things happened together: the base image moved from the floating `python:3.12-slim` to the explicit, pinned `python:3.12.14-slim-bookworm` (Lesson 03's reasoning, applied), and dependency installation was reordered ahead of application source (Lesson 02's caching reasoning, applied).

**Try the rebuild-timing experiment from Lesson 04 again**, this time on this commit, changing a line in `app/main.py` between builds. Compare how much of the build gets reused from cache now versus the naive version.

## Change 2: a real bug, found by building the image properly (`c48ff8d`)

```bash
git show c48ff8d
```

While preparing for a multi-stage build (which relies on `pip install .` producing a *complete* copy of the app), it turned out `pip install .` was silently dropping `app/static/*` - the dashboard's HTML/CSS/JS. Setuptools only bundles `.py` files as package data by default; non-Python files need an explicit `[tool.setuptools.package-data]` entry, which this project's `pyproject.toml` didn't have until now.

This is worth sitting with: the *previous* single-stage Dockerfile never surfaced this bug, because it also had a direct `COPY app ./app` sitting on disk at `/app/app`, and `uvicorn`'s CLI prepends the current working directory to `sys.path` - so the complete, disk-copied version of `app/` was silently shadowing the incomplete, pip-installed one every time. The bug was real and already present; it just hadn't been *observed* yet.

## Questions for the learner (changes 1 and 2)

1. Reproduce the bug yourself: `pip install .` this project into a fresh venv, then check whether `site-packages/app/static/` exists and has files in it, on the commit *before* `c48ff8d`. (Use `git show c48ff8d~1:pyproject.toml` to see the pre-fix file, or check out that commit directly.)
2. Why didn't the single-stage naive Dockerfile from Lesson 04 ever show this bug, even though `pip install .` was already broken in exactly the same way back then?
3. What general lesson does this teach about testing a containerised app by *only* checking that a route like `/health` responds, versus actually exercising the dashboard?

## Change 3: a multi-stage build (`625865e`)

```bash
git show 625865e -- Dockerfile
```

```text
builder
  |
  | full base image + pip + build tooling
  | installs deps into /opt/venv, installs our app, then removes pip/setuptools/wheel from that venv
  v
runtime
  |
  | same base image, but only /opt/venv is copied in
  v
final image: no pip, no setuptools, no wheel, no build metadata at all
```

None of this project's dependencies actually need a compiler - they all ship prebuilt wheels for this platform. So why bother with multi-stage at all? Two real reasons, not ceremony:

1. The final image contains **no package installer whatsoever** - `pip`, `setuptools`, and `wheel` are explicitly uninstalled from the venv before it's copied into the runtime stage. An attacker with code execution inside the container can't just `pip install` more tooling for themselves.
2. It cleanly separates "what it took to build this" from "what it takes to run this" - which pays for itself immediately if this project ever *does* pick up a dependency that needs a compiler.

## Questions for the learner (change 3)

1. If this app's dependencies genuinely needed a C compiler to build (imagine a hypothetical `some-fast-lib` with no prebuilt wheel for this platform), would the *builder* stage need that compiler installed? Would the *runtime* stage?
2. The runtime stage no longer has a `COPY app ./app` line at all - just `COPY --from=builder /opt/venv /opt/venv`. Given Change 2's bug and fix, why is this now correct instead of dangerous?
3. Multi-stage builds aren't always worth their added complexity. Can you think of a Python project - even hypothetically - where a *single*-stage build would be the more honest choice? (Hint: think about a project that's a thin script with one or two pure-Python dependencies and no build step at all.)

## Practical exercise

Run `docker history notes-app:local` (after building the current Dockerfile) and confirm you cannot find `pip`, `setuptools`, or `wheel` anywhere in the final image's layers. Then try running `pip --version` inside a container from this image and confirm it fails.

## Verification / checkpoint

You should be able to explain all three changes in this lesson without looking anything up, and reproduce the static-assets bug from Change 2 in a fresh venv to prove to yourself it was real.

## Recap

The Dockerfile went from "builds and runs" to "builds efficiently, doesn't silently drop application files, and ships without a package installer at runtime" - three separate, real improvements, not one big rewrite. Next: who the process inside the container actually runs as.
