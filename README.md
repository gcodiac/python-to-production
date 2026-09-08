# Notes API

A deliberately small FastAPI application, used as the starting point for a journey from *"it runs on my laptop"* to *"it runs in production."*

Each stage of that journey lives on its own branch, and the **git history is the course** — every commit is one deliberate step.

```mermaid
flowchart LR
    M["main<br/><i>the application</i>"] --> S1["Stage 1<br/>portable app"]
    S1 --> S2["Stage 2<br/>containers"]
    S2 --> S3["<b>Stage 3</b><br/>CI/CD"]
    S3 --> S4["Stage 4<br/>AWS + EKS"]
    S4 --> S5["Stage 5<br/>SRE"]
    style S3 stroke:#2f81f7,stroke-width:4px
```

**You are on Stage 3** (`devops/03-cicd`): every gate Stage 2 taught you to run by hand now runs automatically, on real GitHub Actions, against this actual repository — including a genuine failure that had to be found and fixed.

## Two pipelines

```mermaid
flowchart TD
    PR["Pull request"] --> Q["ruff · pytest (SQLite)<br/>bandit · pip-audit"]
    Q --> PGT["pytest (PostgreSQL)<br/><i>service container</i>"]
    Q --> HL["hadolint"]
    PGT --> BS["build · trivy<br/>smoke test SQLite + PostgreSQL"]
    HL --> BS
    BS --> X(["nothing is published"])

    TAG["Release trigger"] --> B["build <b>ONCE</b>"]
    B --> SC["trivy scan"]
    SC --> SM["smoke test<br/>SQLite + PostgreSQL"]
    SM --> P["push to GHCR"]
    P --> SBOM["SBOM"] --> PROV["provenance"] --> SIG["cosign sign"] --> V["verify"]
    V --> D(["immutable digest"])
    style D stroke:#2f81f7,stroke-width:3px
```

A pull request proves the image *can* be built and works. Only a release publishes — and it publishes **the exact image it just tested**, never a rebuild.

## Two test tiers

```mermaid
flowchart LR
    T1["pytest · SQLite<br/><i>seconds, no services</i>"] --> T2["pytest · PostgreSQL<br/><i>service container</i>"]
    T2 --> T3["<b>built image</b> · PostgreSQL<br/><i>API write verified with psql</i>"]
    style T3 stroke:#2f81f7,stroke-width:3px
```

The same test files run twice — only `DATABASE_URL` changes. The strongest check is the third: the artefact about to be published is run against a real database, and the row it writes over HTTP is read back out with `psql`.

SQLite keeps the inner loop fast; PostgreSQL keeps the fidelity honest. **Parity is not identity** — CI is the right place to pay for the slow one.

## Trust, not just automation

```mermaid
flowchart LR
    S["source commit"] --> I["image digest"]
    I --> SB["SBOM<br/><i>what is inside</i>"]
    I --> PR2["provenance<br/><i>where it came from</i>"]
    I --> SG["signature<br/><i>who built it</i>"]
```

Keyless signing via GitHub's OIDC token — **no private key exists anywhere**. Verification checks the signature was made by *this repository's release workflow*, not merely by "someone":

```bash
cosign verify \
  --certificate-identity-regexp "^https://github.com/<owner>/<repo>/\.github/workflows/release\.yml@.*$" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/<owner>/<repo>@sha256:<digest>
```

## Look at the real runs

```bash
gh run list --limit 10
gh run view <id> --log
```

Nothing in this stage is illustrative YAML. Every workflow here has been executed, observed, and fixed where it broke.

## What this stage added

| | |
|---|---|
| **`pr-checks.yml`** | lint, tests on both databases, Dockerfile lint, build, scan, two smoke tests |
| **`release.yml`** | build once → scan → test → GHCR → SBOM → provenance → sign → verify |
| **`infra-checks.yml`** | (from Stage 4) Terraform and Helm validation, no AWS credentials |
| **Hardening** | every action pinned to a commit SHA, least-privilege `permissions:`, concurrency control |
| **`dependabot.yml`** | automated dependency and action updates |

## Next

📘 **[cicd-learning/](cicd-learning/)** — the 17-lesson course for this stage, from pipeline triggers to signing, provenance, and debugging CI for real.

📄 **[README-extended.md](README-extended.md)** — the long version, with full rationale.

▶️ **Stage 4** — `devops/04-cloud-infrastructure`, where this trusted digest gets promoted into AWS and actually runs.
