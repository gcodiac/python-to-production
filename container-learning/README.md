# Container Engineering & Software Supply Chain

Welcome to Stage 2. Stage 1 ([devops-learning/](../devops-learning/)) answered "what application have I been handed, and what's wrong with it?" This track answers a different question:

> How do I turn that clean application into a reproducible, secure, inspectable, tested deployable artefact?

This is deliberately **not** "write a Dockerfile, run `docker build`, done." A container image is a real software artefact with its own supply chain, its own attack surface, and its own quality bar. This track teaches the professional workflow around building one:

```text
Source
  ↓
Dependencies
  ↓
Build definition
  ↓
Container image
  ↓
Inspect
  ↓
Test
  ↓
Scan
  ↓
Generate SBOM
  ↓
Harden
  ↓
Rebuild
  ↓
Rescan
  ↓
Release candidate
```

## The Git history is part of this course

Every meaningful step of building this container is its own commit on the `devops/02-containerisation-supply-chain` branch, in order. A naive, working-but-imperfect Dockerfile improves one deliberate step at a time, exactly the way a real container gets hardened over a real project's life. You are meant to read the commits, not just the final `Dockerfile`.

```bash
git switch devops/02-containerisation-supply-chain
git log --oneline --reverse devops/01-pre-containerisation..devops/02-containerisation-supply-chain
```

Then look at any individual step:

```bash
git show <commit>
```

or check the whole repository out at that exact point in its history:

```bash
git checkout <commit>
```

That last command puts you in a "detached HEAD" state - you're looking at history, not sitting on a branch tip. It's completely safe to look around, run commands, even build that exact old Dockerfile. When you're done, return to the tip of this branch with:

```bash
git switch devops/02-containerisation-supply-chain
```

## Prerequisites

This track assumes you've completed (or at least read) [devops-learning/](../devops-learning/) - you'll be reusing its `/health` endpoint, its `app/config.py` environment variables, and its `.env.example`. If you haven't got Docker installed yet, install it now (Docker Desktop, or Docker Engine on Linux) - almost every lesson from here on needs it.

## Lessons

| # | Lesson |
|---|--------|
| 00 | [From Source Code to Deployable Artifact](00-from-source-code-to-deployable-artifact.md) |
| 01 | [What Containers Actually Are](01-what-containers-actually-are.md) |
| 02 | [Images, Containers, and Layers](02-images-containers-and-layers.md) |
| 03 | [Choosing a Base Image](03-choosing-a-base-image.md) |
| 04 | [Building the First Image](04-building-the-first-image.md) |
| 05 | [Docker Build Context and .dockerignore](05-docker-build-context-and-dockerignore.md) |
| 06 | [Reproducible Python Dependencies](06-reproducible-python-dependencies.md) |
| 07 | [Improving the Dockerfile](07-improving-the-dockerfile.md) |
| 08 | [Running as Non-Root](08-running-as-non-root.md) |
| 09 | [Runtime Configuration and Secrets](09-runtime-configuration-and-secrets.md) |
| 10 | [Persistent Data and SQLite](10-persistent-data-and-sqlite.md) |
| 11 | [Health Signals and Container Lifecycle](11-health-signals-and-container-lifecycle.md) |
| 12 | [Docker Compose for Local Running](12-docker-compose-for-local-running.md) |
| 13 | [Linting the Dockerfile](13-linting-the-dockerfile.md) |
| 14 | [Signals and Graceful Shutdown](14-signals-and-graceful-shutdown.md) |
| 15 | [Inspecting the Built Image](15-inspecting-the-built-image.md) |
| 16 | [Understanding and Triaging CVEs](16-understanding-and-triaging-cves.md) |
| 17 | [Generating an SBOM](17-generating-an-sbom.md) |
| 18 | [Python Dependency Vulnerability Scanning](18-python-dependency-vulnerability-scanning.md) |
| 19 | [Scanning Container Images](19-scanning-container-images.md) |
| 20 | [Secret and Misconfiguration Scanning](20-secret-and-misconfiguration-scanning.md) |
| 21 | [Container Runtime Hardening](21-container-runtime-hardening.md) |
| 22 | [Container Artifact Testing](22-container-artifact-testing.md) |
| 23 | [OCI Image Metadata and the Software Supply Chain](23-oci-image-metadata-and-the-software-supply-chain.md) |
| 24 | [Building a Manual Release Quality Gate](24-building-a-manual-release-quality-gate.md) |
| 25 | [Ready for CI/CD](25-ready-for-cicd.md) |

(Numbered slightly differently from the order tools were first *mentioned* in this project's brief - lessons 16-20 group CVE triage, SBOMs, and each scanner together by concept rather than strictly by commit order, since that's a clearer way to learn them. The commit history remains the authoritative build order; use `git log --reverse` for that.)

## What you'll have by the end

A production-quality multi-stage `Dockerfile`, a `compose.yaml` for local running, locked and hash-verified Python dependencies, a non-root hardened runtime, persistent SQLite storage via a named volume, a documented dependency/image/secret scanning workflow (`SECURITY.md`), a generated SBOM, and a manual release quality gate (`Makefile` + `scripts/container-smoke-test.sh`) you understand well enough that automating it in CI/CD - the next stage - will feel like a formality, not new material.
