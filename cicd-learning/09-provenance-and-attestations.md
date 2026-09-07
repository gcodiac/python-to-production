# Lesson 09 — Provenance and Attestations

**What you'll learn:** what `actions/attest-build-provenance` actually proves, using this project's real, generated attestation.

## Goal

Understand provenance as a concrete question - "can we prove where this artefact came from?" - and confirm this project can now answer "yes," with evidence.

## Why this matters in real DevOps/platform work

An SBOM (Lesson 08) tells you *what's inside* an artefact. Provenance tells you something different: *how it came to exist*. Both matter, and neither substitutes for the other.

## Concepts

```text
source commit
      +
workflow (which .yml, which run)
      +
builder identity (GitHub's own hosted runner infrastructure)
      +
build inputs (build args, base image reference)
      +
output digest
      =
provenance
```

This project doesn't implement the full SLSA specification (it's a large, formal framework) - the practical target is just: given a published image, can you produce verifiable evidence of the workflow, commit, and builder that produced it? GitHub's `attest-build-provenance` action answers exactly that, using the same OIDC identity mechanism as cosign signing (Lesson 10).

## Investigation steps

### 1. Read the step

```bash
grep -A5 "Generate build provenance attestation" .github/workflows/release.yml
```

### 2. Confirm it ran, for real

```bash
gh run view 34150267799 --log | grep -A2 "subject-digest"
```

### 3. See the attestation itself

```bash
gh attestation verify \
  oci://ghcr.io/gcodiac/python-to-production@sha256:e36d156c9c6ecae7c9ed64e041a2ad46e1e3be5da65c720e316b5dbdc41e29b4 \
  --repo gcodiac/python-to-production
```

(Run in a plain, non-interactive shell/script, add `--format json` - the human-readable summary needs a real terminal to render and prints nothing when piped, even on success. Either way, a zero exit code means verification passed.)

## Questions for the learner

1. `push-to-registry: true` is set on this step. What does that mean is now true about the published image on GHCR - what did it gain beyond the image bytes themselves?
2. This job's permissions include both `id-token: write` and `attestations: write`. Which one is about *proving your identity to Sigstore/GitHub's OIDC provider*, and which is about *actually publishing the resulting record against this repository*?
3. If someone downloaded this project's published image from GHCR without ever looking at this attestation, would the image still run correctly? What would they be missing the ability to verify?

## Practical exercise

Run the `gh attestation verify` command from Step 3 yourself (requires `gh` authenticated with appropriate access) and read its output - it should confirm the exact repository, workflow, and commit that produced this image.

## Verification / checkpoint

You should be able to explain the difference between an SBOM and a provenance attestation in one sentence each, without confusing which answers "what's inside" versus "where did this come from."

## Recap

This project's published image now carries verifiable evidence of its own origin, generated automatically as part of the same run that built it. Next: proving the image hasn't been tampered with since - signing.
