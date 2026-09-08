# Lesson 16 — Ready for Cloud Deployment

**What you'll learn:** what this stage actually accomplished, verified for real, and exactly what Stage 4 will add on top of it.

## Goal

Recap Stage 3 as a whole, using this project's own real, observed results - not a description of what an ideal pipeline would do.

## What this stage actually built and verified

```text
Pull Request                                         (real: #1, gcodiac/python-to-production)
       ↓
Automated quality gates      (Ruff, pytest, Bandit, pip-audit)      - real, passed
       ↓
Automated security gates     (Hadolint, Trivy image scan)           - real, passed
       ↓
Build ONCE                                                            - real, one build step
       ↓
Container image              (ghcr.io/gcodiac/python-to-production)  - real, published
       ↓
Scan                                                                   - real, clean
       ↓
SBOM                         (CycloneDX, 3,418 components)            - real, generated
       ↓
Publish                      (GHCR, tag sha-deb2797)                  - real
       ↓
Immutable digest             (sha256:e36d156c...)                     - real, captured
       ↓
Provenance                   (actions/attest-build-provenance)        - real, attested
       ↓
Signature                    (cosign, keyless/OIDC)                   - real, signed AND independently verified
       ↓
Trusted release artefact
```

Every line above marked "real" is something this stage's own commits, run IDs, and this lesson's author's independent `cosign verify` actually demonstrated - not merely described. This stage even hit a genuine failure (Lesson 02's Bandit severity issue) and fixed it the honest way: observe, understand, fix, commit, push, rerun, verify.

## What's still deliberately missing

* **No cloud deployment anywhere.** Nothing in this stage provisions or touches AWS, Azure, GCP, Kubernetes, or any infrastructure beyond GitHub's own Actions runners and GHCR.
* **No GitHub Environments or required approvals configured** - documented as a recommendation (Lesson 14), not applied.
* **No branch protection configured** - documented as a recommendation (Lesson 15), not applied.
* **`release.yml` still carries a temporary `stage3-test-*` tag trigger**, added specifically because `workflow_dispatch` alone isn't dispatchable until this branch is eventually merged into `main` (Lesson 01). That's a deliberate, temporary, documented workaround - not a permanent feature.

## What Stage 4 (`devops/04-cloud-infrastructure`) will add

```text
Terraform
AWS/cloud architecture
remote Terraform state
networking
IAM
OIDC from GitHub Actions           <- this stage's OIDC pattern, extended to cloud credentials
managed secrets
container runtime
managed database
load balancer
TLS/DNS
environment separation
deployment
autoscaling basics
backup/recovery
infrastructure security scanning
cost awareness
```

Notice the OIDC pattern from Lesson 12 doesn't get reinvented for cloud access - it gets *extended*. The same "short-lived, workflow-scoped identity instead of a long-lived stored key" principle that signed this project's image will be how Stage 4's workflows authenticate to real cloud infrastructure.

## Questions for the learner

1. This project's real published image (`sha256:e36d156c...`) already exists on GHCR right now. What, specifically, does Stage 4 still need to do before that exact image is actually serving real traffic anywhere?
2. Why does it make sense that the *same* OIDC concept from Lesson 12 (GitHub identity → short-lived credential) is what Stage 4 will reach for, rather than a completely different cloud-authentication approach?
3. If you were reviewing this repository today, cold, what would you check first to confirm this stage's claims are real rather than aspirational? (This is a genuine, answerable question - the tools are `gh run list`, `gh run view`, and `cosign verify`, all used throughout this track.)

## Practical exercise

Write a short paragraph - the last piece of writing in this track - as if handing this repository to a teammate about to start Stage 4. Name the exact published digest, confirm it's signed and attested, and name the two or three things (environments, branch protection, the temporary tag trigger) they should know are still open before this becomes a fully production-grade pipeline.

## Verification / checkpoint

You should be able to explain, using only this project's real commit history and real Actions run IDs, why this stage's claim to be "not fabricated" holds up - and name exactly what's still missing before Stage 4 can begin.

## Recap

This project now has a real, automated, verified path from a pull request to a signed, attested, published container image - built once, never rebuilt, trusted for a documented reason at every step. Cloud infrastructure and actual deployment are next, and they inherit this stage's identity model rather than replacing it.
