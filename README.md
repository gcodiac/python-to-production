# Minimal Notes API (FastAPI)

A deliberately small Python web application designed to serve as a starting point for learning how applications evolve from local development to production.

The application is intentionally kept minimal. It contains only the core application functionality needed to run and test locally, without introducing production infrastructure, deployment automation, cloud configuration, containerization, observability, or other platform concerns.

The goal is to provide a simple application that can be forked and progressively improved while learning topics such as Platform Engineering, DevOps, Infrastructure as Code, cloud infrastructure, security, monitoring, observability, and SRE.

## Five learning tracks

This repository supports five learning paths, all grounded in this exact application, each picking up where the last one left off:

```text
Track 1
Python / FastAPI Development                  (learning/)
        ↓
Track 2
DevOps Pre-Containerisation                    (devops-learning/, devops/01-pre-containerisation)
        ↓
Track 3
Container Engineering & Supply Chain           (container-learning/, devops/02-containerisation-supply-chain)
        ↓
Track 4
CI/CD, Registry, Signing & Provenance          (cicd-learning/, devops/03-cicd)
        ↓
Track 5
AWS, Terraform, Kubernetes & EKS               (cloud-learning/, devops/04-cloud-infrastructure)
        ↓
FINAL
SRE / Production Operations                    (a later stage, not yet in this repository)
```

* **[learning/](learning/) — Application Development / FastAPI.** New to Python or FastAPI? This 22-lesson course builds this exact Notes API from an empty folder, from absolute basics through a finished, tested app with a working dashboard.
* **[devops-learning/](devops-learning/) — DevOps / Platform Engineering.** Already have this app (or one like it)? This 14-lesson course puts you in the position of a platform/DevOps engineer *receiving* an already-built application from a development team, and walks you through understanding, analysing, and preparing it for containerisation — investigation, static and security analysis, and environment-based configuration, all *before* a single `Dockerfile` gets written. Lives on the `devops/01-pre-containerisation` branch (and, from that branch onward).
* **[container-learning/](container-learning/) — Container Engineering & Software Supply Chain.** Takes the clean, remediated application from Track 2 and turns it into a real, inspected, tested, scanned, hardened container artefact: a production-quality multi-stage `Dockerfile`, locked dependencies, non-root runtime, persistent storage, a `compose.yaml`, dependency/image/secret scanning (`SECURITY.md`), an SBOM, and a manual release quality gate — deliberately stopping short of CI/CD. Lives on the `devops/02-containerisation-supply-chain` branch.
* **[cicd-learning/](cicd-learning/) — CI/CD, Registry, Signing & Provenance.** Automates Track 3's manual release gate with real GitHub Actions against this repository's actual GitHub remote: pull-request quality/security gates, a build-once/scan/publish-to-GHCR/SBOM/provenance/cosign-signing release workflow, and Dependabot — verified with real, observed Actions runs (including a genuine failure that was found and fixed), not just written YAML. Lives on the `devops/03-cicd` branch, with an open, unmerged Pull Request (#1) against `devops/02-containerisation-supply-chain`.
* **[cloud-learning/](cloud-learning/) — AWS, Terraform, Kubernetes & EKS.** Takes the trusted artefact from Track 4 and actually runs it: a real VPC, EKS cluster, managed node group, private ECR, and RDS PostgreSQL, all defined in Terraform, with the application deployed by Helm from GitHub Actions using OIDC (no stored AWS keys) and reading its database password from Secrets Manager via EKS Pod Identity. Includes an honest lesson on why ECS Fargate would arguably be the better engineering choice for an app this small, and why the course chooses EKS anyway. Lives on the `devops/04-cloud-infrastructure` branch.

You don't have to complete one track to start the next, but each assumes familiarity with what the previous one built. Tracks 2, 3, 4 and 5 live on their own branches specifically so their git history can teach the *process* of hardening an application/image/pipeline one deliberate step at a time - see each track's README for how to read that history.

## Why is it so minimal?

Most example applications already include many production-oriented decisions before explaining why they are needed. This project takes the opposite approach: start with a small application that works locally, then introduce production requirements only when the problems they solve become relevant.

The application therefore deliberately begins without:

* environment-based configuration
* containerization
* production databases
* deployment pipelines
* cloud infrastructure
* secret management
* production logging
* monitoring and observability
* infrastructure-specific configuration

These are not missing features. They are intentionally left for the learning journey that begins after forking this repository.

**This branch (`devops/01-pre-containerisation`) has since addressed several of them** as part of a completed pre-containerisation review: configuration (`APP_ENV`, `APP_HOST`, `APP_PORT`, `DATABASE_URL`, `LOG_LEVEL`, `APP_SECRET`) is now externalised via environment variables and `app/config.py` (see `.env.example`), and the application fails loudly rather than starting insecurely if `APP_SECRET` is missing in production. Earlier commits on this branch deliberately introduced a small set of code-quality and configuration/security problems for the [devops-learning/](devops-learning/) track to find, each originally marked with a comment containing `TRAINING-ISSUE`. If you want to work through that investigation yourself rather than see the finished result, check out an earlier commit on this branch (before the "Fix static analysis findings" commit) and run `grep -rn "TRAINING-ISSUE" app/` there — the lessons in [devops-learning/](devops-learning/) still describe that exercise in full. The current tip of this branch is the worked example of what completing it looks like.

## What this application contains

* a small FastAPI application (`app/main.py`)
* a simple Notes API (create, read, update, delete) plus a `/health` endpoint
* a glassmorphic dashboard UI (`app/static/`) served at `/`, built with plain HTML/CSS/JS against the API — no frontend framework or build step
* SQLite for local persistence (`app/database.py`)
* environment-based configuration (`app/config.py`, `.env.example`)
* basic automated tests (`tests/test_notes.py`)
* Python project configuration (`pyproject.toml`) and locked dependencies (`requirements.txt`, `requirements-dev.txt`)
* a production-quality container image (`Dockerfile`, `.dockerignore`, `compose.yaml`) and its security scanning results (`SECURITY.md`) — see the [container-learning/](container-learning/) track
* real GitHub Actions CI/CD (`.github/workflows/`) and dependency-update automation (`.github/dependabot.yml`) — see the [cicd-learning/](cicd-learning/) track
* AWS infrastructure as code (`infra/`) and Kubernetes packaging (`k8s/`) for a real EKS deployment — see the [cloud-learning/](cloud-learning/) track

## Running locally

```bash
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"

cp .env.example .env   # first time only - adjust values as needed

uvicorn app.main:app --reload
```

The dashboard is now available at `http://127.0.0.1:8000`. Interactive API docs are available at `http://127.0.0.1:8000/docs`.

Configuration is read from environment variables (see `.env.example` for the full list) with safe local-development defaults, except `APP_SECRET`, which the app refuses to start without whenever `APP_ENV=production`.

## Running the tests

```bash
pytest
```

## Running in a container

On the `devops/02-containerisation-supply-chain` branch, the same application also runs as a container — see [container-learning/](container-learning/) for how the `Dockerfile` and `compose.yaml` got there, one deliberate step at a time.

```bash
cp .env.example .env
docker compose up --build
```

The manual release quality gate (tests, linting, security scanning, image scanning, SBOM generation) is documented in `SECURITY.md` and wrapped in `Makefile` (`make check`) once you're comfortable with the individual commands it runs.

## API

| Method | Path          | Description        |
|--------|---------------|---------------------|
| GET    | `/notes`      | List all notes      |
| POST   | `/notes`      | Create a note        |
| GET    | `/notes/{id}` | Get a single note    |
| PUT    | `/notes/{id}` | Update a note         |
| DELETE | `/notes/{id}` | Delete a note         |
| GET    | `/health`     | Basic liveness/readiness check |

A note has the shape:

```json
{
  "id": 1,
  "title": "Groceries",
  "content": "Milk, eggs",
  "created_at": "2026-08-25 12:00:00"
}
```

## Intended use

This repository acts as a reusable starting application. A learner can fork it and take the application through a complete journey from:

```text
Local application
        ↓
Understanding & analysing an inherited app   (devops-learning/, devops/01-pre-containerisation)
        ↓
Application configuration                     (devops-learning/ - complete on that branch)
        ↓
Containerization                                 (container-learning/, devops/02-containerisation-supply-chain)
        ↓
Container security, SBOMs, manual release gate     (container-learning/ - complete on that branch)
        ↓
CI/CD, registry, signing, provenance                 (cicd-learning/, devops/03-cicd - complete on that branch)   <- you are here
        ↓
Infrastructure as Code
        ↓
Cloud infrastructure
        ↓
Production databases
        ↓
Networking and security
        ↓
Monitoring and observability
        ↓
Reliability and production operations
```

The application should remain simple enough that the focus stays on understanding the engineering required around the application rather than on application business logic.
