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
| 04 | [Building Containers in CI](04-building-containers-in-ci.md) |
| 05 | [Container Scanning in CI](05-container-scanning-in-ci.md) |
| 06 | [Registries, Tags, and Digests](06-registries-tags-and-digests.md) |
| 07 | [Build Once, Promote Many](07-build-once-promote-many.md) |
| 08 | [SBOMs and Release Artifacts](08-sboms-and-release-artifacts.md) |
| 09 | [Provenance and Attestations](09-provenance-and-attestations.md) |
| 10 | [Signing and Verifying Images](10-signing-and-verifying-images.md) |
| 11 | [CI/CD Secrets, Permissions, and OIDC](11-cicd-secrets-permissions-and-oidc.md) |
| 12 | [Dependency Update Automation](12-dependency-update-automation.md) |
| 13 | [Releases, Environments, and Approvals](13-releases-environments-and-approvals.md) |
| 14 | [Debugging and Operating CI/CD](14-debugging-and-operating-cicd.md) |
| 15 | [Ready for Cloud Deployment](15-ready-for-cloud-deployment.md) |

## What you'll have by the end

Two real GitHub Actions workflows (`.github/workflows/pr-checks.yml`, `.github/workflows/release.yml`), a Dependabot configuration, and a genuine understanding - because you watched it happen - of what "build once, scan it, sign it, prove where it came from" actually looks like on real infrastructure.
