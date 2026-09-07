# Thin wrappers around the raw commands taught throughout devops-learning/
# and container-learning/ - see
# container-learning/25-building-a-manual-release-quality-gate.md, which is
# the lesson this file assembles into one target.
#
# This file is deliberately NOT where you learn what these commands do -
# read the lessons and run them by hand first. `make check` exists so that,
# once you understand every step, you don't have to retype all of them by
# hand every single time.

.PHONY: test lint security audit hadolint scan sbom grype build run run-postgres container-test postgres-test check

test:
	pytest

lint:
	ruff check app/

security:
	bandit -r app/ --severity-level medium

audit:
	pip-audit -r requirements.txt
	pip-audit -r requirements-dev.txt

hadolint:
	hadolint Dockerfile

build:
	docker build --build-arg GIT_REVISION=$$(git rev-parse --short HEAD) -t notes-app:local .

# Local mode A: application + SQLite in a named volume.
run:
	docker compose up --build

# Local mode B: application + a real PostgreSQL server. Same image, same
# Dockerfile - only the runtime topology differs.
run-postgres:
	docker compose -f compose.postgres.yaml up --build

# Both smoke tests require an image built via `make build` first, and both
# run that one image. Neither builds anything.
container-test:
	./scripts/container-smoke-test.sh

postgres-test:
	./scripts/postgres-smoke-test.sh

scan:
	mkdir -p reports
	trivy fs --scanners vuln,secret,misconfig --exit-code 1 .
	trivy config --exit-code 1 Dockerfile

sbom:
	mkdir -p reports
	syft dir:. --source-name notes-app --source-version 0.1.0 \
	    -o cyclonedx-json=reports/sbom.cdx.json \
	    -o spdx-json=reports/sbom.spdx.json

grype: sbom
	grype sbom:reports/sbom.cdx.json --fail-on medium

# The full manual release quality gate, source to release candidate - see
# container-learning/25-building-a-manual-release-quality-gate.md. Every
# one of these steps is something you should already be able to run and
# explain by hand before you ever rely on this target.
#
# Note that `build` happens once, and BOTH smoke tests run against that one
# image. If a release gate had to build a separate image per database, the
# application would not actually be portable - it would just have two builds.
check: test lint security audit hadolint build container-test postgres-test scan sbom grype
	@echo "All release-gate checks passed (SQLite and PostgreSQL)."
