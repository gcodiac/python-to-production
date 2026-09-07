# Lesson 00 — From Source Code to Deployable Artifact

**What you'll learn:** what "Stage 2" actually means, and the professional workflow this whole track follows.

## Goal

Understand why containerising an application is a process with real engineering steps, not a single command, before you write a single line of Dockerfile.

## Why this matters in real DevOps/platform work

`docker build` succeeding tells you almost nothing. It doesn't tell you the image is small, secure, running as the right user, free of known vulnerabilities, or actually able to serve real traffic. Teams that treat "it builds" as "it's done" are the teams that get paged at 2am because a container was running as root, or shipped a secret baked into a layer, or silently lost its database on every redeploy. This track exists to build the habit of treating a container image the way you'd treat any other release artefact: built, inspected, tested, and scanned before it's trusted.

## Concepts

* **Artefact** — a specific, versioned, buildable output of your source code (here: a container image) that you can hand to someone else and expect to behave identically.
* **Reproducible build** — building the same source twice produces an equivalent, trustworthy result, not "whatever happened to resolve from the internet this time."
* **Release candidate** — an artefact that has passed every check your team considers mandatory before it's allowed to run anywhere that matters.

## The workflow this track follows

```text
Source
  ↓
Dependencies
  ↓
Build definition
  ↓
Container image
  ↓
Inspect
  ↓
Test
  ↓
Scan
  ↓
Generate SBOM
  ↓
Harden
  ↓
Rebuild
  ↓
Rescan
  ↓
Release candidate
```

Every one of those steps gets its own lesson and its own commit on this branch. None of them are optional busywork - each one exists because skipping it is a real, documented way projects get hurt in production.

## Investigation steps

Before moving on, get oriented in the current state of the branch:

```bash
git log --oneline --reverse devops/01-pre-containerisation..devops/02-containerisation-supply-chain
```

## Questions for the learner

1. Why might "the image built successfully" and "the image is safe to run in production" be two completely different claims?
2. Look at the commit list you just printed. Without reading a single diff yet, what do you predict each commit changes, based on its message alone?

## Practical exercise

Write, in your own words, one sentence describing what "software supply chain" means for a container image (you'll refine this understanding across lessons 17-19 and 23 - this is just your starting guess).

## Verification / checkpoint

You should be able to recite the ten-step workflow above from memory by the end of this track, and explain in one sentence why each step exists.

## Recap

Containerising an application is a process, not a single command - and that process has a name and a shape you'll now follow one deliberate step at a time. Next: what a container actually *is*, before you build one.
