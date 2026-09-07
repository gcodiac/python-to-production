# Thin wrappers around the raw commands taught throughout devops-learning/
# and container-learning/ - see container-learning/29 (Makefile) and
# container-learning/28 (the manual release quality gate this assembles).
#
# This file is deliberately NOT where you learn what these commands do -
# read the lessons and run them by hand first. `make check` exists so that,
# once you understand every step, you don't have to retype all of them by
# hand every single time.

.PHONY: test lint security audit hadolint scan sbom grype build run container-test check

test:
	pytest

lint:
	ruff check app/

security:
	bandit -r app/

audit:
	pip-audit -r requirements.txt
	pip-audit -r requirements-dev.txt

hadolint:
	hadolint Dockerfile

build:
	docker build --build-arg GIT_REVISION=$$(git rev-parse --short HEAD) -t notes-app:local .

run:
	docker compose up --build

# Requires an image built via `make build` first.
container-test:
	./scripts/container-smoke-test.sh

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
# container-learning/28-building-a-manual-release-quality-gate.md. Every
# one of these steps is something you should already be able to run and
# explain by hand before you ever rely on this target.
check: test lint security audit hadolint build container-test scan sbom grype
	@echo "All release-gate checks passed."
