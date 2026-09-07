# Security Scanning

This document records what security tooling this project runs, why each tool
exists (they check different things - see
`container-learning/18-python-dependency-vulnerability-scanning.md` and
`container-learning/19-scanning-container-images.md` for the full reasoning),
and the most recent results. Regenerate everything below with the commands
shown; raw output goes to the git-ignored `reports/` directory.

## Tooling overview

| Tool | Checks | Category |
|---|---|---|
| `ruff` / `bandit` | our Python source | code quality / security patterns (Stage 1) |
| `pip-audit` | known CVEs in our *resolved Python dependencies* | dependency vulnerability scanning |
| `hadolint` | the `Dockerfile` itself | Dockerfile linting |
| `trivy` (fs/config) | source tree: vulnerable deps, exposed secrets, Dockerfile misconfiguration | container-adjacent scanning, no image required |

`pip-audit` and Bandit are not the same thing: Bandit looks for risky
*patterns in code we wrote*; `pip-audit` looks for *known vulnerabilities in
packages we depend on*, regardless of whether our code even uses the
vulnerable part.

## Python dependency vulnerability scanning (pip-audit)

```bash
pip install pip-audit
pip-audit -r requirements.txt
pip-audit -r requirements-dev.txt
```

**Result (most recent run): no known vulnerabilities found**, for both the
runtime (`requirements.txt`) and development (`requirements-dev.txt`) locked
dependency sets.

## Source-tree scanning (Trivy, no image required)

Trivy's `fs` and `config` subcommands scan the working tree directly -
useful long before an image exists:

```bash
trivy fs --scanners vuln,secret,misconfig .
trivy config Dockerfile
```

**Result (most recent run): no vulnerabilities, no exposed secrets, no
Dockerfile misconfigurations found.**

Two honest limitations worth knowing, rather than assuming full coverage:

* Trivy's pip vulnerability detection looks for a file named exactly
  `requirements.txt` - it does not automatically pick up
  `requirements-dev.txt`. `pip-audit` above already covers that file
  explicitly.
* Trivy's misconfiguration checks understand `Dockerfile`s (and Kubernetes/
  Terraform/CloudFormation manifests) but have no Compose-specific rules -
  pointing it at `compose.yaml` finds nothing to check, not "zero issues."

## Dockerfile linting (Hadolint)

```bash
hadolint Dockerfile
```

**Result (most recent run): no findings.** Earlier, naive versions of this
Dockerfile (still visible in this branch's git history) did trigger findings
along the way - see `container-learning/13-linting-the-dockerfile.md` for
what was found and fixed, and why Hadolint's default rules don't catch
everything (missing non-root user, missing dependency-layer caching) the way
a broader review does - the same lesson Stage 1 taught about Ruff vs.
SonarQube, applied to Dockerfiles.

## What this project deliberately did not need to fix

Every scan above came back clean. That is reported here as a genuine result,
not because findings were hidden - see `container-learning/16-understanding-and-triaging-cves.md`
for how this project would triage and document a real finding if one showed up.
