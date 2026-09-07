# Lesson 08 — Running as Non-Root

**What you'll learn:** why this project's process runs as an explicit, unprivileged user - matching commit `e53dc6e` - and how to actually verify that, rather than assume it.

## Goal

Verify, with real commands, that this container runs as a named, non-root, uid-1000 user, and understand exactly what that buys you.

## Why this matters in real DevOps/platform work

Unless a Dockerfile says otherwise, a container's main process runs as root *inside the container* by default. That's the single most common finding in any container security review of a codebase that hasn't had one yet. It's an easy, cheap fix, and skipping it is one of the fastest ways to fail a security audit for no good reason.

## Concepts

* **Container root ≠ host root.** Root inside a container's own PID/mount namespace is not the same as root on the underlying host - Docker's default configuration already isolates a great deal. This is often used (wrongly) as a reason to not bother with non-root containers.
* **Defence in depth.** Even though container root isn't host root, running as non-root still meaningfully limits what code running inside the container can do to *the container's own filesystem and process tree* - which matters a great deal the moment there's a container escape vulnerability, a misconfigured volume mount, or simply a dependency vulnerability being actively exploited. Depth of defence, not a single silver bullet.

## Investigation steps

### 1. Read the relevant Dockerfile section

```bash
git show e53dc6e -- Dockerfile
```

### 2. Verify it, once you have Docker available

```bash
docker build -t notes-app:local .
docker run --rm notes-app:local id
```

or, on a running container:

```bash
docker exec <container-name-or-id> whoami
docker exec <container-name-or-id> id
```

## Questions for the learner

1. The Dockerfile creates a group and user both explicitly at uid/gid `1000`, then later does `USER 1000:1000` (numeric), not `USER appuser` (by name). Lesson 13 covers exactly why Hadolint prefers the numeric form - what's the risk with the named form that the numeric form avoids?
2. `chown -R appuser:appuser /app` runs *before* `USER 1000:1000` in the Dockerfile. Why does the order matter here - what would happen if `USER` came first?
3. `useradd` is given `--no-create-home` and `--shell /usr/sbin/nologin`. Neither of those is strictly required for the app to work. Why include them anyway?

## Expected observations

`docker run --rm notes-app:local id` should print something like `uid=1000(appuser) gid=1000(appuser) groups=1000(appuser)` - never `uid=0(root)`.

## Practical exercise

As an experiment (don't leave this in the real Dockerfile), temporarily comment out the `USER 1000:1000` line, rebuild, and run `id` again. Confirm it now reports root. Then restore the line, rebuild, and confirm it's back to uid 1000. This is the fastest way to *prove* to yourself that this one line is doing real work, not just looking correct.

## Verification / checkpoint

You should have real command output (not just this project's Dockerfile comments) proving the running container is uid 1000, not root.

## Recap

This container runs as an explicit, unprivileged, verifiable user - a small change with a real, measurable security benefit. Next: how runtime configuration (the Stage 1 environment variables) actually reaches this container once it's built.
