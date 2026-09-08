# Lesson 05 — Building Containers in CI

**What you'll learn:** how `docker/build-push-action` and `docker/setup-buildx-action` build this project's real image on a GitHub-hosted runner - and confirmation that it actually worked.

## Goal

Understand the `build-and-scan` job's build step, and see the real, successful build from this project's own CI history.

## Why this matters in real DevOps/platform work

Stage 2 was built and verified in an environment with no Docker daemon at all - every build/run instruction was authored and reviewed by hand, never executed. GitHub-hosted Actions runners *do* have Docker pre-installed, which is exactly why this stage is where this project's `Dockerfile` finally got built and run for real, automatically, for the first time.

## Concepts

* **Buildx** — Docker's modern builder frontend (BuildKit), needed for advanced features like the registry-backed cache this project uses. `docker/setup-buildx-action` prepares it on the runner.
* **`docker/build-push-action`** — the standard, well-maintained action wrapping `docker buildx build`, supporting build args, caching, and (later, in `release.yml`) pushing.
- **`load: true`, `push: false`** — this project's PR job builds the image and loads it into the runner's local Docker daemon (so it can be scanned and smoke-tested) without ever pushing it anywhere. See Lesson 08.

## Investigation steps

### 1. Read the build step

```bash
sed -n '/Build image (not published)/,/cache-to/p' .github/workflows/pr-checks.yml
```

### 2. See a real, successful build in this project's history

```bash
gh run view 34149482129 --log | grep -A2 "Build image (not published)"
```

That run (commit `11773b0`, the same one that fixed the Bandit issue) is this project's first real, GitHub-hosted, working `docker build` of this exact Dockerfile.

### 3. Notice the build-arg

```bash
grep -A2 "build-args" .github/workflows/pr-checks.yml
```

`GIT_REVISION=${{ github.sha }}` feeds Stage 2's OCI `org.opencontainers.image.revision` label with the real commit SHA being validated - not a placeholder.

## Questions for the learner

1. This project only builds for `linux/amd64` (the runner's native platform) - there's no multi-platform build here. What would you need to add if this image also needed to run on `linux/arm64` (e.g. Apple Silicon developer machines, or AWS Graviton), and why does this project not bother?
2. `cache-from: type=gha` / `cache-to: type=gha,mode=max` use GitHub's own Actions cache backend. What happens to a build if that cache is completely empty (e.g. the very first run ever, or after the cache expires)? Does the build fail, or just take longer?
3. Reconnect to Stage 2's software-supply-chain lesson: this build step is the exact same `Dockerfile`, same locked `requirements.txt`, same pinned base image - now executed on infrastructure you don't control (a GitHub-hosted runner) instead of your own machine. What does that change about *what* you're trusting, if anything?

## Practical exercise

Compare the build step's duration across the two real runs you've already seen (`34149340197`'s partial run vs. `34149482129`'s full run, and the later `34150267799` release run). Cache warms up after the first successful run - by the second or third build, you should see build time drop noticeably for unchanged layers.

## Verification / checkpoint

You should be able to point at a real, specific GitHub Actions run ID from this project's history and say "that is where this Dockerfile was built successfully by a machine, for the first time."

## Recap

The image build that Stage 2 could only ever describe correctly on paper has now actually happened, repeatedly, on real infrastructure. Next: what happens to that built image before anyone trusts it.
