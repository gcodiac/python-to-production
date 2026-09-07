# Lesson 09 — ECR and Artifact Promotion

**What you'll learn:** why the image moves from GHCR to ECR, and how to move it **without rebuilding** — preserving the Stage 3 chain of trust.

## Goal

Understand promotion as a *copy*, and be able to explain what would be lost by rebuilding instead.

## Why ECR at all?

The trusted image already exists in GHCR. Copying it to ECR buys:

* **IAM-native authentication** — nodes pull with their instance role; no registry credentials in the cluster.
* **Locality** — same region as the cluster; faster pulls, no cross-internet data transfer.
* **Lifecycle policies** — automatic cleanup of old training images.

```bash
grep -A20 'resource "aws_ecr_repository"' ../infra/environments/staging/main.tf
```

The repository is **private** (ECR repositories are private unless you explicitly create a *public* repository), encrypted, `IMMUTABLE`-tagged, and has a lifecycle policy keeping only the 10 most recent images.

`scan_on_push = true` enables ECR **basic** scanning, which is free. It does **not** enable *enhanced* scanning, which routes through Amazon Inspector and bills per image. Trivy remains this course's primary scanner; ECR basic scanning is a free second opinion.

## The rule: promotion never rebuilds

```text
source
  ↓
Stage 3 release controls   (test, scan, SBOM, provenance, signature)
  ↓
trusted GHCR artefact
  ↓
verify signature
  ↓
copy / promote            <- NO BUILD HAPPENS HERE
  ↓
ECR
  ↓
deploy exact ECR digest
```

Rebuilding at promotion time would silently discard everything Stage 3 established: the thing deployed would no longer be the thing that was tested, scanned and signed — merely something built from the same source, at a different moment, with potentially different transitive dependencies or base-image content.

## How the copy is done

Not with `docker pull && docker push` — that round-trips through a local daemon and invites a rebuild-shaped mistake. Instead, an OCI-aware registry copy:

```bash
crane copy ghcr.io/gcodiac/python-to-production@sha256:<digest> \
           <account>.dkr.ecr.eu-west-1.amazonaws.com/notes-app-staging:sha-<commit>
```

`crane` (from go-containerregistry) copies manifests and layers registry-to-registry. No daemon, no build, no possibility of substituting different content.

```bash
grep -A20 "Promote image to ECR" ../.github/workflows/deploy-staging.yml
```

## Verify before you promote

The deploy workflow refuses to promote an arbitrary tag. It first re-verifies the Stage 3 signature:

```bash
grep -A6 "Verify the Stage 3 signature" ../.github/workflows/deploy-staging.yml
```

This checks both the Sigstore OIDC issuer and that the signing identity was *this repository's* `release.yml` workflow. An image someone pushed to GHCR by other means would fail this check and never reach AWS.

## About digests across registries

The deployment invariant is: **no application rebuild occurred.**

Whether the ECR digest is byte-identical to the GHCR digest depends on registry behaviour. A straight manifest copy usually preserves the digest exactly. It can legitimately differ if a registry recomputes or converts the manifest (for example media-type normalisation, or how referrers/attestations are stored). The workflow reports both digests and states plainly which case occurred rather than assuming equality:

```bash
grep -A8 "digests identical" ../.github/workflows/deploy-staging.yml
```

Do not claim digest equality you have not observed — claim the invariant you actually guarantee.

## Deploying by digest

The Helm chart refuses to render without a digest:

```bash
grep -A8 "notes-app.image" ../k8s/charts/notes-app/templates/_helpers.tpl
```

```bash
helm template notes-app ../k8s/charts/notes-app -f ../k8s/values/staging.yaml \
  --set image.repository=example/notes-app
# Error: image.digest is required - deploy by immutable digest, not a tag
```

A mutable tag would break traceability from a running Pod back to one exact scanned, signed artefact.

## Questions for the learner

1. What exactly is lost if promotion rebuilds the image from the same commit?
2. Why is `crane copy` preferable to `docker pull` + `docker push` for this?
3. The chart hard-fails on a missing digest instead of falling back to `:latest`. Why is failing better here?

## Recap

Promotion moves the exact trusted artefact into a private, regional registry and deploys it by immutable digest — the Stage 3 guarantee extended into AWS rather than quietly discarded. Next: the database it talks to.
