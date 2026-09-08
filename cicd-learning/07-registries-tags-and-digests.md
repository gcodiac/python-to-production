# Lesson 07 — Registries, Tags, and Digests

**What you'll learn:** the difference between a tag and a digest, using this project's real, published GHCR image as the example - not a hypothetical one.

## Goal

Explain the difference between "human-friendly pointer" and "exact immutable content identity," and quote this project's actual published tag and digest from memory (or by looking them up correctly).

## Why this matters in real DevOps/platform work

"Which version is actually running in production" is a question every incident, rollback, and audit eventually asks. If the honest answer is "whatever `:latest` happened to point to at some point," you don't actually have an answer.

## Concepts

```text
tag
=
human-friendly pointer (can be reassigned to a different image later)

digest
=
exact immutable content identity (sha256:..., can never change meaning)
```

* This project's release workflow tags every published image `sha-<short-commit-sha>` - traceable to an exact commit, but still technically a mutable tag (nothing stops someone from re-pushing to the same tag).
* The **digest** is what `docker push` returns and what this project's SBOM, provenance attestation, and signature all actually reference - not the tag.
* This project never relies on `:latest` as an authoritative pointer - see `release.yml`'s tagging logic.

## Investigation steps

### 1. See this project's real published image reference

```bash
gh run view 34150267799 --log | grep "Published digest"
```

You should find: `ghcr.io/gcodiac/python-to-production` tagged `sha-deb2797`, with digest `sha256:e36d156c9c6ecae7c9ed64e041a2ad46e1e3be5da65c720e316b5dbdc41e29b4`.

### 2. See how the digest was captured, mechanically

```bash
grep -A8 "name: Publish to GHCR" .github/workflows/release.yml
```

## Questions for the learner

1. If this exact image were re-tagged as `sha-deb2797` again later, pointing at a *different* build (say, after a base-image security patch), would the tag change? Would the digest of the *original* image change?
2. This project's SBOM, provenance attestation, and cosign signature (Lessons 08-10) all reference `${{ env.IMAGE_NAME }}@${{ steps.publish.outputs.digest }}` - a digest, not a tag. Why does that matter for someone verifying those artefacts *later*, potentially after other tags have been reused?
3. Why is an `extra_tag` input available on `release.yml` at all, given everything above emphasises digests over tags? What's a tag still genuinely useful for, even knowing it's not the authoritative identity?

## Practical exercise

Using the real digest from Step 1, write out (don't execute - see Lesson 15 for real verification commands) what a `docker pull` by digest, rather than by tag, would look like:

```text
docker pull ghcr.io/gcodiac/python-to-production@sha256:e36d156c9c6ecae7c9ed64e041a2ad46e1e3be5da65c720e316b5dbdc41e29b4
```

Explain, in one sentence, why this command can never silently pull a different image than the one this project actually built and scanned - unlike pulling by tag alone.

## Verification / checkpoint

You should be able to state, correctly, this project's actual published digest (or how to find it again from the run log), and explain why every downstream artefact (SBOM, attestation, signature) is anchored to it rather than to the tag.

## Recap

A tag is a convenience; a digest is the truth. This project's entire chain of trust - from build through signature - is anchored to the digest, on purpose. Next: why the image that gets scanned must be the exact same image that gets published.
