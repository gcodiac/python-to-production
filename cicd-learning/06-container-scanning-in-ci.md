# Lesson 06 — Container Scanning in CI

**What you'll learn:** the report-vs-block scanning policy this project actually enforces, and confirmation of the real result Trivy produced against the real built image.

## Goal

Understand exactly what `aquasecurity/trivy-action` blocks on in this project, and see the real scan result from CI - the first time this project's *actual built image* (not just its source tree, as in Stage 2) was ever scanned.

## Why this matters in real DevOps/platform work

Stage 2 could only run `trivy fs`/`trivy config` against the source tree - there was no Docker daemon available to build an image to scan. This is the first point in the whole course where Trivy scans the *real, built container image*, including its OS-level packages, exactly the gap Stage 2 flagged as unverified.

## The policy

```yaml
- name: Trivy image scan
  uses: aquasecurity/trivy-action@...
  with:
    image-ref: notes-app:pr-check
    severity: HIGH,CRITICAL
    ignore-unfixed: true
    exit-code: "1"
```

* **`severity: HIGH,CRITICAL`** — only these severities can fail the build. Lower severities are still reported in the log, just not blocking.
* **`ignore-unfixed: true`** — don't fail on a vulnerability with no available fix yet. There is nothing actionable you can do about it today except accept and document it (Lesson 10's spirit, applied here) - failing the build over it just trains people to ignore red X's.
* **`exit-code: "1"`** — without this, Trivy would report findings but never actually fail the step.

## Investigation steps

### 1. See the real result

```bash
gh run view 34149482129 --log | grep -B2 -A15 "Trivy image scan" | head -40
```

### 2. Confirm this policy is applied consistently

```bash
grep -B1 -A4 "severity: HIGH,CRITICAL" .github/workflows/*.yml
```

Both `pr-checks.yml` and `release.yml` apply the exact same policy - a PR should never be held to a looser (or stricter) standard than the actual release gate it's protecting.

## Questions for the learner

1. This project's real image scan came back clean - no HIGH/CRITICAL fixable findings on `python:3.12.14-slim-bookworm` plus this project's three direct dependencies. Does a clean result here mean the image has *zero* vulnerabilities of any kind? Re-read the policy above.
2. If Trivy found a HIGH-severity, fixable vulnerability in a transitive OS package tomorrow (a routine Debian security update, say), what would actually happen to this PR? What would your remediation options be, connecting back to Lesson 16 of Stage 2's triage workflow?
3. Why does scanning happen *after* the build but *before* anything gets published (in `release.yml`)? What would go wrong about the "build once, promote many" story (Lesson 08) if scanning happened after publishing instead?

## Practical exercise

Read `SECURITY.md`'s note about Trivy's Stage 2 limitation - that it could only run `fs`/`config` scans, never `image`, for lack of a Docker daemon. Update your own understanding: as of this stage, that gap is closed for real, and the actual command that closed it is the one you just read in Step 1.

## Verification / checkpoint

You should be able to quote this project's exact severity/ignore-unfixed policy from memory, and explain why each of its three settings exists.

## Recap

The image-scanning gap Stage 2 could only describe is now closed, verified, and enforced automatically, with a policy that blocks what's actionable and reports what isn't. Next: what it means to publish this image somewhere real.
