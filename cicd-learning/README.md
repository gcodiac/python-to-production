# CI/CD, Registry, Signing & Provenance

Stage 2 ([container-learning/](../container-learning/)) taught a manual workflow: run the tests, run the linters, build the image, scan it, generate an SBOM, and only then trust the result. This track automates that exact process - safely, consistently, and for real, on this repository's actual GitHub Actions.

```text
source
  ↓
test
  ↓
lint
  ↓
security checks
  ↓
build image
  ↓
scan image
  ↓
SBOM
  ↓
release-quality artefact          <- Stage 2 got you here, by hand
```

## Where the database fits

This track is also where database portability stops being a promise and becomes a checked property:

```text
Stage 1   the application source supports SQLite AND PostgreSQL
   ↓
Stage 2   a developer can run either one locally, same image
   ↓
Stage 3   CI verifies both on every change          <- this track
   ↓
Stage 4   the cloud supplies managed PostgreSQL
```

CI runs two tiers deliberately: the whole suite on SQLite in seconds, then the *same* suite against a real PostgreSQL service container, and finally the built image itself against PostgreSQL before anything is published. Lesson 04 covers why the fast tier is worth keeping rather than making everyone pay PostgreSQL's cost on every push.

becomes:

```text
Developer change
       ↓
Pull Request
       ↓
Automated quality gates
       ↓
Automated security gates
       ↓
Build ONCE
       ↓
Container image
       ↓
Scan
       ↓
SBOM
       ↓
Publish
       ↓
Immutable digest
       ↓
Provenance
       ↓
Signature
       ↓
Trusted release artefact          <- this track gets you here, automatically
```

## This is real, not example YAML

Unlike some earlier material, this track's workflows actually ran on GitHub Actions against this real repository (`gcodiac/python-to-production`), including a genuine failure that was found, understood, and fixed - see Lesson 02 and this branch's commit `11773b0`. Every "PASS" claimed in this track's lessons or the accompanying report is something that was actually observed in a real Actions run, not assumed.

## The Git history is part of this course

```bash
git switch devops/03-cicd
git log --oneline --reverse devops/02-containerisation-supply-chain..devops/03-cicd
```

Then inspect any step:

```bash
git show <commit>
```

or check the repository out at that exact point:

```bash
git checkout <commit>
```

This puts you in a "detached HEAD" state - safe to look around, nothing to break. Return to the tip of this branch with:

```bash
git switch devops/03-cicd
```

There's also a real, open Pull Request for this branch - see the root `README.md` or this repository's Pull Requests tab for the link. Its checks tab shows the exact same runs referenced throughout this track.

## Prerequisites

This track assumes [container-learning/](../container-learning/) - you'll be reusing its `Dockerfile`, `compose.yaml`, and its whole toolchain (Ruff, Bandit, pip-audit, Hadolint, Trivy, Syft), just automated instead of run by hand.

## Lessons

| # | Lesson |
|---|--------|
| 00 | [From Manual Checks to CI/CD](00-from-manual-checks-to-cicd.md) |
| 01 | [CI/CD and Pipeline Triggers](01-ci-cd-and-pipeline-triggers.md) |
| 02 | [Pull Request Quality Gates](02-pull-request-quality-gates.md) |
| 03 | [Security and Dependency Gates](03-security-and-dependency-gates.md) |
| 04 | [Verifying Database Portability in CI](04-verifying-database-portability-in-ci.md) |
| 05 | [Building Containers in CI](05-building-containers-in-ci.md) |
| 06 | [Container Scanning in CI](06-container-scanning-in-ci.md) |
| 07 | [Registries, Tags, and Digests](07-registries-tags-and-digests.md) |
| 08 | [Build Once, Promote Many](08-build-once-promote-many.md) |
| 09 | [SBOMs and Release Artifacts](09-sboms-and-release-artifacts.md) |
| 10 | [Provenance and Attestations](10-provenance-and-attestations.md) |
| 11 | [Signing and Verifying Images](11-signing-and-verifying-images.md) |
| 12 | [CI/CD Secrets, Permissions, and OIDC](12-cicd-secrets-permissions-and-oidc.md) |
| 13 | [Dependency Update Automation](13-dependency-update-automation.md) |
| 14 | [Releases, Environments, and Approvals](14-releases-environments-and-approvals.md) |
| 15 | [Debugging and Operating CI/CD](15-debugging-and-operating-cicd.md) |
| 16 | [Ready for Cloud Deployment](16-ready-for-cloud-deployment.md) |

## What you'll have by the end

Two real GitHub Actions workflows (`.github/workflows/pr-checks.yml`, `.github/workflows/release.yml`), a Dependabot configuration, and a genuine understanding - because you watched it happen - of what "build once, scan it, sign it, prove where it came from" actually looks like on real infrastructure.
