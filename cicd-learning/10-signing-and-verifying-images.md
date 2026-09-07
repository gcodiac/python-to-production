# Lesson 10 — Signing and Verifying Images

**What you'll learn:** keyless image signing with cosign and GitHub's OIDC identity, verified twice - once inside the workflow, once independently, from outside GitHub Actions entirely.

## Goal

Understand why this project has no signing key anywhere, and reproduce the exact verification this lesson's author ran against the real published image.

## Why this matters in real DevOps/platform work

> "A signature exists" is not enough. The expected signer identity matters.

A signature only means something if you also check *who* signed it. A malicious actor could sign their own tampered image with their *own* key just as easily as a legitimate pipeline signs a real one - the signature alone proves nothing without an expected identity to check it against.

## Concepts

```text
BAD: long-lived signing key
     generated once, stored as a secret, used forever, can leak

GOOD: keyless signing via OIDC
      image digest
          ↓
      sign (ephemeral certificate, minutes-long validity, tied to this exact workflow run)
          ↓
      identity-bound signature
          ↓
      verify (against expected issuer + expected workflow identity)
```

This project's `release.yml` never generates, stores, or references a private key anywhere - see the `sign` step's plain `cosign sign --yes <image>@<digest>`. Cosign requests a short-lived signing certificate from Sigstore's public infrastructure, using GitHub's OIDC token to prove "this really is a run of `gcodiac/python-to-production`'s `release.yml`" - and that's the entire trust basis.

## Investigation steps

### 1. Read both steps

```bash
grep -A3 "Sign the published image" .github/workflows/release.yml
grep -A6 "Verify the signature" .github/workflows/release.yml
```

Notice the verify step checks **both** the OIDC issuer (`https://token.actions.githubusercontent.com` - "this came from *some* GitHub Actions run") **and** a certificate-identity regexp scoped to this exact repository and workflow file (`.../release.yml@...` - "specifically *this* workflow, not just any GitHub Actions run anywhere").

### 2. Confirm it happened inside the real run

```bash
gh run view 34150267799 --log | grep -A3 "Sign the published image\|Verify the signature"
```

### 3. Verify it yourself, independently, right now

```bash
cosign verify \
  --certificate-identity-regexp "^https://github.com/gcodiac/python-to-production/\.github/workflows/release\.yml@.*$" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/gcodiac/python-to-production@sha256:e36d156c9c6ecae7c9ed64e041a2ad46e1e3be5da65c720e316b5dbdc41e29b4
```

This is not a hypothetical - running this exact command (as this lesson's author did) against this project's real published image succeeds, and prints two verified claims: a `slsa.dev/provenance/v1` entry (Lesson 09's attestation) and a `sigstore.dev/cosign/sign/v1` entry (this signature) - both bound to the same docker manifest digest.

## Questions for the learner

1. What would happen to the verify command above if you narrowed `--certificate-identity-regexp` to match only `pr-checks.yml` instead of `release.yml`? Would verification still succeed?
2. Cosign's signing certificate is described as "ephemeral" - valid for only minutes. If someone stole a copy of it an hour later, could they sign a new, different image and have it pass this same verification? Why or why not?
3. Where does the actual signature get stored - is it embedded in the image itself, or somewhere else? (Hint: look up "Sigstore transparency log" / Rekor conceptually - you don't need to operate one, just know it exists as the public, append-only record cosign checks against.)

## Practical exercise

Run the verify command from Step 3 yourself. Confirm your own local run reports the same two claims (provenance + signature) referenced above, both anchored to the exact digest `sha256:e36d156c9c6ecae7c9ed64e041a2ad46e1e3be5da65c720e316b5dbdc41e29b4`.

## Verification / checkpoint

You should have run `cosign verify` yourself, independently, from your own machine (not just trusted the workflow's own internal "Verify the signature" step), and gotten a real, successful result against this project's real published image.

## Recap

This project's release image is signed with no key that exists anywhere to steal, and that signature has now been checked twice - once automatically inside the pipeline, once independently, right now, by you. Next: the permission and identity model that made all of this possible without a single stored secret.
