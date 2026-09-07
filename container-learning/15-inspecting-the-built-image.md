# Lesson 15 — Inspecting the Built Image

**What you'll learn:** how to look inside an image without guessing - size, layers, configured user, environment, command, labels, health configuration - and how to compare the naive first image against the current one.

## Goal

Produce a real, evidence-based inspection report of `notes-app:local`, and compare it against `notes-app:naive` from Lesson 04.

## Why this matters in real DevOps/platform work

"What's actually in this image?" is a question you should always be able to answer with commands, not assumptions - especially for an image someone else built, or one you built months ago and no longer remember the details of.

## Investigation steps

### 1. Basic size and identity

```bash
docker image ls notes-app
```

### 2. Full configuration

```bash
docker inspect notes-app:local
```

Specifically worth reading closely:

```bash
docker inspect --format='{{json .Config.User}}' notes-app:local
docker inspect --format='{{json .Config.Env}}' notes-app:local | python3 -m json.tool
docker inspect --format='{{json .Config.Cmd}}' notes-app:local
docker inspect --format='{{json .Config.Entrypoint}}' notes-app:local
docker inspect --format='{{json .Config.Labels}}' notes-app:local | python3 -m json.tool
docker inspect --format='{{json .Config.Healthcheck}}' notes-app:local | python3 -m json.tool
```

### 3. Layer history

```bash
docker history notes-app:local
```

### 4. Filesystem contents, safely, without leaving anything running

```bash
docker run --rm notes-app:local find / -maxdepth 3 -newer /etc/hostname -type f 2>/dev/null
```

(This is a rough approximation of "what did the build actually add" - a real diff against the base image, via `docker diff` on a *stopped* container derived from the base image alone, is more precise if you want to go further.)

## Questions for the learner

1. What user does `.Config.User` report? Does it match what Lesson 08's `id` check showed you?
2. What does `.Config.Env` contain? Should any of Stage 1's six configuration variables (`APP_ENV`, `APP_HOST`, `APP_PORT`, `DATABASE_URL`, `LOG_LEVEL`, `APP_SECRET`) appear here? (Reconnect this to Lesson 09 - if any of them *did* show up here, that would mean they got baked in somewhere they shouldn't have.)
3. Look at `docker history`'s output for the runtime stage specifically. How many layers actually contributed meaningful size, versus metadata-only layers (`ENV`, `USER`, `LABEL`, `HEALTHCHECK`, `CMD` add no filesystem content)?

## Practical exercise

Run this exact inspection sequence against both images and record the numbers side by side:

```bash
docker image ls notes-app:naive notes-app:local
```

Write down, in your own notes: the size of each, and one sentence on what specifically accounts for the difference (dependency layer caching doesn't change final size - multi-stage removing pip/setuptools/wheel does; base image choice was the same in both, so that's not the difference here).

## Verification / checkpoint

You should have real, copy-pasted command output (not assumptions) for: the image's configured user, its environment variables, its command, its labels, and its health check configuration.

## Recap

Everything an image will do at runtime - who it runs as, what it runs, what's configured, how its health is checked - is inspectable before you ever start a container from it. Next: what that size difference between the naive and current image actually means, and doesn't mean.
