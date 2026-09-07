# Lesson 20 — Scanning Container Images

**What you'll learn:** why a container image needs scanning beyond just its Python dependencies, using Trivy - matching commit `5ced40e` - and an honest gap in what could be verified while this lesson was written.

## Goal

Understand what Trivy scans that `pip-audit` structurally cannot, and run the checks that don't require a built image, while knowing exactly what still needs to happen once one exists.

## Why this matters in real DevOps/platform work

```text
Container image
├── Linux packages       <- pip-audit never sees these
├── Python runtime
├── Python dependencies  <- pip-audit's whole job
└── our application
```

An image is a full filesystem. Debian/Ubuntu/Alpine base images ship real OS packages with their own CVE history - `pip-audit` has no visibility into any of it. This is why Trivy (or an equivalent image scanner) is a separate, necessary tool, not a nicer version of `pip-audit`.

## An honest note on what was actually run

This lesson (and this branch's `SECURITY.md`) was authored in an environment with **no working Docker daemon available** - a genuine constraint, not a shortcut. That means `trivy image notes-app:local`, which needs either a running Docker daemon or an exported image tarball, could not be run here. What *was* run, and works without any container runtime at all:

```bash
trivy fs --scanners vuln,secret,misconfig .
trivy config Dockerfile
```

**Result (most recent run): no vulnerabilities, no exposed secrets, no misconfigurations found** in the source tree and Dockerfile - see `SECURITY.md`.

## What you should run, once you have Docker

```bash
docker build -t notes-app:local .
trivy image notes-app:local
```

This is the check that actually covers the full picture from the diagram above - OS packages included. Do this before trusting this project's container as a real release candidate; don't take the source-tree-only result as equivalent.

## Investigation steps

### 1. Confirm what mode you're running Trivy in, and why it matters

```bash
trivy fs --help | head -5
trivy image --help | head -5
```

Notice these are genuinely different subcommands with different inputs - `fs` walks a filesystem/directory, `image` needs an actual container image reference.

### 2. Run what doesn't need Docker, right now

```bash
mkdir -p reports
trivy fs --scanners vuln,secret,misconfig --format json --output reports/trivy-fs.json .
trivy config Dockerfile
```

## Questions for the learner

1. Why can't `trivy fs .` see the vulnerabilities (if any existed) in the base image's OS packages, the way `trivy image` would?
2. `SECURITY.md` notes that Trivy's pip vulnerability detection specifically looks for a file named `requirements.txt`, and doesn't automatically also check `requirements-dev.txt`. Given that, is `trivy fs .`'s clean result on its own sufficient evidence that the dev dependencies are clean too? What already covers that gap? (Lesson 19.)
3. Once you've run `trivy image notes-app:local` yourself, compare its finding count to `trivy fs .`'s. If it finds more, what category do you expect those extra findings to be in?

## Practical exercise

If you have Docker available: build the image, run `trivy image notes-app:local`, and update this project's `SECURITY.md` with the real result, replacing the "not run in this environment" caveat with an actual finding count (even if it's zero). If you don't have Docker available yet, write out - in your own notes - exactly what you'd expect to see, and why source-tree scanning alone isn't sufficient to close this out.

## Verification / checkpoint

You should be able to state clearly, without hand-waving: which specific Trivy checks were actually run and produced a real result for this project, and which one (`trivy image`) still needs a working Docker install to complete properly.

## Recap

Scanning a source tree and Dockerfile is real, useful coverage - but it is not the same claim as scanning the actual built image, and this lesson said so plainly rather than pretending otherwise. Next: the specific, sharpest edge of image scanning - secrets that shouldn't be there at all.
