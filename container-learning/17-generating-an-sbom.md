# Lesson 17 — Generating an SBOM

**What you'll learn:** what a Software Bill of Materials actually is, and how to generate one for this project with Syft - matching commit `a7df2fa`.

## Goal

Generate a real SBOM for this project in an industry-standard format, and understand exactly what question it answers that scanning alone doesn't.

## Why this matters in real DevOps/platform work

> A critical vulnerability is discovered tomorrow in some component. Which of your deployed images actually contain it?

Without an SBOM, answering that question means re-scanning everything you've ever shipped, hoping your scanner's vulnerability database has caught up, and hoping you kept every old image around to scan. With an SBOM already generated at build time, it's a search through inventory you already have.

## Concepts

```text
container image (or, here, source tree)
      ↓
inventory
      ↓
SBOM
```

* **SBOM** — Software Bill of Materials: a complete, structured inventory of every component (and its exact version) that makes up a piece of software - the software equivalent of an ingredients list.
* **CycloneDX** and **SPDX** — the two dominant machine-readable SBOM formats. Neither is "more correct" than the other; different consumers/tools prefer different ones, so this project generates both.

## Installing Syft

```bash
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b ~/.local/bin
syft --version
```

## Investigation steps

### 1. Generate both formats

```bash
mkdir -p reports
syft dir:. --source-name notes-app --source-version 0.1.0 \
    -o cyclonedx-json=reports/sbom.cdx.json \
    -o spdx-json=reports/sbom.spdx.json \
    -o table
```

### 2. Look at what's actually in it

```bash
python3 -c "
import json
data = json.load(open('reports/sbom.cdx.json'))
print(f\"{len(data['components'])} components\")
for c in data['components'][:5]:
    print(c['name'], c['version'])
"
```

## Questions for the learner

1. This SBOM was generated with `syft dir:.` - scanning the *source tree* (via `requirements.txt`/`requirements-dev.txt`), not a built image. What's missing from it that a full image SBOM (`syft notes-app:local`, once you have Docker running) would include? (Hint: think about what layers of the final image aren't Python packages at all.)
2. Why does this project generate the SBOM as a build/release-time artefact rather than committing it to git? (Reconnect to Stage 1's "generated files shouldn't be hand-edited or treated as source of truth" instinct.)
3. Both `pip-audit` (Lesson 18) and this SBOM inventory this project's Python dependencies. Are they redundant? What does one give you that the other doesn't?

## Expected observations

The generated CycloneDX/SPDX SBOM lists every resolved Python package (direct and transitive) this project depends on, by exact name and version - the same set `requirements.txt`/`requirements-dev.txt` already lock, just in a portable, tool-agnostic, industry-standard format that other tools (like Grype, next) can consume directly.

## Practical exercise

Once you have Docker available, generate a *second* SBOM directly from the built image (`syft notes-app:local -o cyclonedx-json=reports/sbom-image.cdx.json`) and diff its component list against the source-tree SBOM you generated above. The image-based one should additionally include Debian/OS-level packages that only exist once an actual filesystem has been built - a concrete illustration of the gap this lesson's Question 1 asked about.

## Verification / checkpoint

You should have two real SBOM files in `reports/` (gitignored, regenerable), in two different standard formats, and be able to explain in one sentence why an SBOM is useful *independent of* whether a vulnerability scan finds anything right now.

## Recap

An SBOM is inventory, generated once and reusable for as long as the artefact exists - independent of any specific scan result. Next: an actual vulnerability scan, but from the Python-dependency angle specifically.
