# Lesson 08 — SBOMs and Release Artifacts

**What you'll learn:** how `anchore/sbom-action` generates a real SBOM for this project's actual published image, and where to find it.

## Goal

Retrieve the real SBOM this project's release run generated, and understand why it's attached to the *artefact*, not just produced as a build log.

## Why this matters in real DevOps/platform work

> An SBOM is useful because it tells us what is actually inside a particular released artefact.

Stage 2 could only generate an SBOM from the *source tree* (`syft dir:.`) - there was no built image to point at. This is the first SBOM in the whole course generated against a real, published container image, referenced by its exact digest.

## Investigation steps

### 1. Read the step

```bash
grep -A6 "Generate SBOM for the published image" .github/workflows/release.yml
```

Notice it targets `${{ env.IMAGE_NAME }}@${{ steps.publish.outputs.digest }}` - the digest, not a tag (Lesson 06).

### 2. Confirm it ran for real

```bash
gh run view 34150267799 --log | grep -i "sbom\|cyclonedx"
```

### 3. Download the actual artefact

```bash
gh run download 34150267799 --name sbom-deb2797 --dir /tmp/notes-app-sbom
cat /tmp/notes-app-sbom/sbom.cdx.json | python3 -m json.tool | head -30
```

## Questions for the learner

1. Compare this SBOM's component list (from the real, built image) against Stage 2's source-tree-only SBOM (`container-learning/17-generating-an-sbom.md`). What categories of components would you now expect to see here that weren't in Stage 2's version? (Hint: OS packages - see container-learning's own honesty note about this exact gap.)
2. Why is this SBOM uploaded as a GitHub Actions artifact (`actions/upload-artifact`) with a 30-day retention, rather than committed to the git repository the way `SECURITY.md` is?
3. Revisit the "critical vulnerability discovered tomorrow" question from Stage 2. Now that a real SBOM exists for a real published digest, what would answering that question actually look like in practice - what would you search, and for what?

## Practical exercise

Open the downloaded SBOM and count how many components it lists:

```bash
python3 -c "import json; print(len(json.load(open('/tmp/notes-app-sbom/sbom.cdx.json'))['components']))"
```

This project's real image SBOM lists **3,418 components** - compare that to Stage 2's source-tree-only SBOM, which listed **57**. That roughly 60x difference is almost entirely Debian OS packages (`dpkg`-tracked libraries, utilities, and their dependencies) that only exist once an actual filesystem has been built - exactly the gap Stage 2's own SBOM lesson predicted but couldn't demonstrate.

## Verification / checkpoint

You should have a real SBOM file downloaded from this project's actual release run, generated against the actual published digest - not a description of what one would contain.

## Recap

This project now has a genuine, artefact-linked Software Bill of Materials, closing a gap Stage 2 could only name. Next: proving *where* this artefact came from, not just *what's in it*.
