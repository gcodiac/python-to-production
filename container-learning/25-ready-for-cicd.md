# Lesson 25 — Ready for CI/CD

**What you'll learn:** what this branch actually accomplished, and what Stage 3 will automate, but not implement yet.

## Goal

Recap Stage 2 as a whole, and understand precisely why CI/CD, image signing, provenance, and cloud deployment are all deliberately absent from this branch.

## What this branch built

```text
clean source (from devops/01-pre-containerisation)
   +
reproducible dependencies (Lesson 06)
   +
production-quality Dockerfile (Lessons 02-07)
   +
non-root runtime (Lesson 08)
   +
runtime configuration, no baked-in secrets (Lesson 09)
   +
persistent storage (Lesson 10)
   +
health/lifecycle handling (Lessons 11, 14)
   +
Compose environment (Lesson 12)
   +
dependency scanning (Lesson 18)
   +
container scanning (Lessons 19-20)
   +
SBOM (Lesson 17)
   +
runtime hardening (Lesson 21)
   +
manual release quality gate (Lesson 24)
   =
RELEASE-QUALITY CONTAINER ARTEFACT
```

Every one of those was a real, verified, git-committed step - not a description of what an ideal project *would* have.

## Why this stopped short of CI/CD

Everything in this track was run **by hand**, on purpose. That wasn't a limitation to work around - it was the point. `make check` (Lesson 24) is already a thin wrapper around commands you now understand individually. The moment you automate that sequence in a CI platform without having done it by hand first, you've automated something you don't actually understand - and you'll be debugging pipeline failures blind.

## What Stage 3 (`devops/03-cicd`) will cover

```text
GitHub Actions / CI platform
PR quality gates
tests
linting
SAST
dependency scanning
container build
container scanning
SBOM generation
registry publishing
immutable image digests
image signing
build provenance / attestations
dependency update automation
release tagging
environment promotion
deployment approvals
```

Notice: almost every item on that list is a tool or check *this track already introduced*. Stage 3's job is turning "I run this by hand, in this order, and I know what each result means" into "a machine runs this on every pull request, and blocks merges that fail it." The *checks* don't change. What runs them does.

## Questions for the learner

1. Pick any three items from the Stage 3 list above. For each, name which lesson in *this* track already taught you the underlying concept, even though it wasn't automated here.
2. Image signing and provenance were mentioned conceptually in Lesson 23 but not implemented. Why do both genuinely need automation (a pipeline, not a human) to be trustworthy?
3. If someone handed you this exact repository right now and asked "is this ready to containerise and deploy," what would your honest answer be - and what, specifically, would you still want CI/CD (not more manual work) to add before you'd deploy it somewhere that mattered?

## Practical exercise

Write a short paragraph - the last piece of writing in this track - as if handing this branch off to a teammate who's about to set up CI/CD for it. Name what's already solid (be specific: which commit did what), and name the one or two things you'd flag as "still needs Stage 3" rather than "still broken."

## Verification / checkpoint

You should be able to explain, without hedging, why this branch is genuinely release-quality as a manually-verified artefact, and why "manually verified" and "ready for unattended automated deployment" are still two different bars - the second one is what Stage 3 exists to clear.

## Recap

This branch took a clean, Stage-1-remediated application and turned it into a real, inspected, tested, scanned, hardened container artefact - built one understandable, committed step at a time, exactly the way the Git history on this branch tells it. The next stage automates this same process; it does not need to reinvent it.
