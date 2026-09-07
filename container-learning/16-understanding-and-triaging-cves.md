# Lesson 16 — Understanding and Triaging CVEs

**What you'll learn:** a professional triage workflow for a security scanner finding, and why "the scanner found something" and "you have an incident" are different claims - before you run a single scanner in the next few lessons.

## Goal

Learn the triage workflow itself, so that when Lessons 18-20's tools produce output, you already know exactly what to do with it - whether it's clean (as this project's scans currently are) or not.

## Why this matters in real DevOps/platform work

The single most common failure mode with security scanners isn't missing them - it's mismanaging their output. Teams either ignore every finding ("too much noise") or panic-fix everything regardless of relevance ("it says CRITICAL, drop everything"). Both are wrong for the same reason: neither actually evaluates whether the finding matters *here*.

## Concepts

* **CVE** — Common Vulnerabilities and Exposures: a public, unique identifier for a specific known vulnerability (e.g. `CVE-2024-12345`).
* **Advisory identifiers** — CVEs aren't the only scheme; you'll also see `GHSA-...` (GitHub Security Advisory) and tool-specific IDs. Same underlying concept: "this specific version range of this specific package has this specific known problem."
* **Vulnerable version / fixed version** — a CVE record specifies which version range is affected, and (usually) which version first fixed it.
* **Direct vs. transitive** — is the affected package one you chose, or something a dependency of yours pulled in without your direct awareness? (Lesson 06 introduced this distinction; it matters again here because *how* you remediate differs - upgrade your own pin, versus wait for/nudge an upstream maintainer to bump theirs.)

## The triage workflow

```text
finding
  ↓
which component?
  ↓
which version?
  ↓
is our version affected?
  ↓
is there a fix?
  ↓
is vulnerable behaviour reachable/relevant to how we actually use this component?
  ↓
severity and context
  ↓
upgrade / mitigate / document exception
```

Two things to hold in tension:

> A scanner finding does not automatically equal an exploitable incident.

but also:

> Scanner findings should not be casually ignored.

Both are true. The triage workflow above is how you resolve that tension for a specific finding, instead of picking a side in general.

## Questions for the learner

1. Suppose a scanner flags `CVE-2024-XXXXX` in a JSON-parsing library, describing a vulnerability that's only exploitable when parsing untrusted YAML input. Your project uses that library, but only for parsing your own `compose.yaml` at build time, never untrusted input. Walk through the triage workflow above for this hypothetical - where does it land, and why?
2. If a fix exists (a newer patched version) but upgrading would require a major version bump with breaking API changes, what are your actual options, beyond "upgrade immediately" or "ignore it"?
3. What does it mean to "document an exception," concretely? What information would you want written down, for a future reader (including future you) to trust that the exception was a deliberate decision and not an oversight?

## What "document a remaining finding" means in this project

If a real finding ever survives triage without a fix (this project currently has none - see `SECURITY.md`), the record should include:

* component and affected version
* severity
* whether a fixed version exists
* the reasoning for why it's accepted (reachability, context) or a note that remediation is planned
* where this decision lives (a comment near the relevant lock-file entry, or a note in `SECURITY.md`)

## Practical exercise

Pick any real, currently-published CVE for a well-known Python package (search "CVE python package" for a recent example) and walk it through the triage workflow above as a hypothetical: what would you need to check to know if *this exact project* were affected, even though it almost certainly isn't (unless coincidentally using that exact package)?

## Verification / checkpoint

You should be able to recite the triage workflow from memory, and explain, in one sentence each, why "scanner finding ≠ incident" and "don't ignore findings" are not actually contradictory.

## Recap

You now have the framework for handling scanner output *before* you generate any - which means Lessons 17-20's tool output won't tempt you into either extreme. Next: giving yourself the actual inventory this triage workflow needs to work from - an SBOM.
