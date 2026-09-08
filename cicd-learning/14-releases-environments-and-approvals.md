# Lesson 14 — Releases, Environments, and Approvals

**What you'll learn:** semantic versioning in brief, GitHub Environments and approvals conceptually, and this project's recommended (but not yet applied) branch protection settings.

## Goal

Understand how a Git tag, an image digest, and an approval gate relate to each other - and know exactly which of these this project has actually configured versus merely documented.

## Semantic versioning, briefly

```text
MAJOR.MINOR.PATCH
```

* **MAJOR** — incompatible/breaking change.
* **MINOR** — backwards-compatible new feature.
* **PATCH** — backwards-compatible fix.

This project does not build an elaborate version-management system. A future tag like `v1.0.0` would correspond to exactly **one** immutable image digest - not a rebuild. For this stage's practical exercise, a manually-dispatched training build (this project used a temporary `stage3-test-1` tag - see Lesson 01) was sufficient; there was no real product version to name yet.

## Environments and promotion, conceptually

```text
development  →  test  →  staging  →  APPROVAL  →  production
```

Environments typically differ by configuration, secrets, and infrastructure - never by rebuilding the artefact:

```text
BUILD
  ↓
sha256:e36d156c... (this project's real, published digest)
  ↓
TEST
  ↓
STAGING
  ↓
APPROVAL
  ↓
PRODUCTION

still sha256:e36d156c...
```

This is Lesson 08's principle again, extended across environments rather than just within one workflow run.

## GitHub Environments and approvals, conceptually

GitHub Environments let you require manual approval before a job can deploy *to* a specific environment (e.g. `production`, but not `staging`). This project does **not** configure any GitHub Environments - there is nothing to deploy to yet (Stage 4's job). Recommended setup for when that changes:

```text
staging     -> automatic (no approval required)
production  -> required reviewers configured on the Environment
```

## Investigation steps

### 1. Confirm this project has no environments configured yet

```bash
gh api repos/gcodiac/python-to-production/environments 2>&1
```

### 2. Read how this project currently avoids needing one

```bash
grep -B3 "workflow_dispatch" .github/workflows/release.yml
```

A manual trigger is itself a (lightweight) approval gate - someone has to actively choose to run it.

## Questions for the learner

1. Why is "the same image digest gets promoted through every environment" specifically what makes an approval gate *meaningful*? What would an approval before "rebuild and deploy to production" actually be approving, if the rebuild could produce something subtly different from what was tested in staging?
2. This project's release trigger is `workflow_dispatch` (plus a temporary tag - Lesson 01). Is that itself a form of "approval," in the sense this lesson describes? What's missing compared to a real GitHub Environment approval gate?
3. If this project tagged a real `v1.0.0` release tomorrow, should that trigger a *new build*, or should it apply a new tag to the *already-published* digest from an existing successful run? Justify your answer from Lesson 08.

## Practical exercise

Run the command from Investigation Step 1 yourself and confirm the honest, current answer (no environments configured). Write, in your own words, the exact GitHub UI steps you'd take to add a `production` environment with one required reviewer - without actually doing it.

## Verification / checkpoint

You should be able to state clearly which of "semantic versioning," "environments," and "approval gates" this project has actually implemented versus merely documented as a recommendation for later.

## Recap

A digest, once built and proven, is the thing that should move through environments - never rebuilt, only re-approved. Next: what to do when any of this automation itself breaks.
