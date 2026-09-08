# Lesson 12 — CI/CD Secrets, Permissions, and OIDC

**What you'll learn:** why this project's two workflows request different, minimal permissions, what OIDC actually replaces, and the real attack surface a CI/CD pipeline has.

## Goal

Justify, line by line, every permission this project's workflows request - and name none it doesn't.

## Why this matters in real DevOps/platform work

A CI token is a credential. `permissions: write-all` on a workflow that only runs tests is the CI/CD equivalent of running a web app as root "just in case" - it works, right up until something goes wrong, at which point it goes very wrong.

## This project's actual permissions

```bash
grep -A2 "^permissions:" .github/workflows/pr-checks.yml
grep -B2 -A6 "^    permissions:" .github/workflows/release.yml
```

| Workflow | Permission | Why |
|---|---|---|
| `pr-checks.yml` | `contents: read` | Only ever checks out code and runs local checks. Never publishes anything. |
| `release.yml` | `contents: read` | Checkout. |
| `release.yml` | `packages: write` | Push the image to GHCR. |
| `release.yml` | `id-token: write` | Request a short-lived OIDC token, used for both cosign keyless signing and the provenance attestation. |
| `release.yml` | `attestations: write` | Publish the provenance attestation against this repository. |

No workflow in this project uses `write-all`, and none has a permission it doesn't have a step that actually needs.

## Concepts

* **Repository secret / environment secret** — encrypted values stored in GitHub, injected into a workflow run. This project defines **zero** custom secrets - `secrets.GITHUB_TOKEN` (used once, for the GHCR login) is automatically generated per-run by GitHub itself, not something anyone configured.
* **Repository/environment variable** — non-secret configuration (this project doesn't currently need any at the CI level; `env.IMAGE_NAME` in `release.yml` is computed from `github.repository`, not stored separately).
* **Runtime application secret** — `APP_SECRET` (Stage 1/2) is a *different* category entirely: it configures the running *application*, not the CI pipeline. Nothing in this project's CI/CD ever sets, reads, or needs it.
* **OIDC (OpenID Connect)** — instead of storing a long-lived credential as a secret, the workflow requests a short-lived, cryptographically verifiable identity token from GitHub, scoped to exactly this run. Sigstore (Lesson 11) and the provenance attestation (Lesson 10) both rely on this rather than any stored key.

## Real CI/CD attack surfaces, kept practical

* **Secrets leaked to logs** — never `echo` a secret; this project never handles a real secret at all in CI, sidestepping the risk entirely.
* **Overly broad `GITHUB_TOKEN`** — see the permissions table above; each workflow requests only what it uses.
* **Malicious PR code / dangerous fork workflows** — `pr-checks.yml` never has publishing credentials available to it at all (no `packages:write`, no `id-token:write`), so even a maliciously modified PR branch cannot exfiltrate a real credential or publish a real release - see Lesson 13.
* **Mutable third-party Actions** — every third-party action in both workflows is pinned to a full commit SHA, not a floating tag - see this project's action-pinning commits and comments (e.g. `# v7.0.1` alongside the SHA).
* **Compromised base images / dependencies** — this is exactly what Trivy, `pip-audit`, and Dependabot (Lesson 13) exist to catch.
* **Publishing from untrusted branches** — `release.yml` is never triggered by a `pull_request` event at all.

## Questions for the learner

1. If `release.yml` accidentally requested `contents: write` as well, what could a compromised step in that workflow now do to this repository that it currently cannot?
2. `secrets.GITHUB_TOKEN` is used for the GHCR login step. Why doesn't cosign signing or the provenance attestation also need it - what do they use instead?
3. Suppose a contributor opened a pull request from a fork with a modified `pr-checks.yml` that tried to add `packages: write` to itself. Would that PR's workflow actually gain that permission when it runs? (This is a real, well-known GitHub Actions safety property worth confirming, not assuming.)

## Practical exercise

Read every `uses:` line in both workflow files and confirm each references a full 40-character commit SHA, with a version-tag comment alongside it. Pick one (e.g. `docker/build-push-action`) and verify independently that the SHA actually corresponds to the tagged release claimed in the comment:

```bash
gh api repos/docker/build-push-action/commits/v7.3.0 --jq .sha
```

## Verification / checkpoint

You should be able to recite this project's complete permission set from memory, and explain why `pr-checks.yml` structurally *cannot* leak a publishing credential even if the PR code itself were malicious.

## Recap

This project's entire CI/CD trust model runs on zero long-lived custom secrets, minimal per-workflow permissions, and OIDC-issued short-lived identity everywhere a credential is actually needed. Next: keeping dependencies (including these very Actions) up to date, safely.
