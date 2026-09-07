# Lesson 01 — What Containers Actually Are

**What you'll learn:** the real relationship between an image, a container, a process, and a registry - the vocabulary every later lesson depends on.

## Goal

Be able to explain, precisely, what happens between writing a `Dockerfile` and having a running application - and stop using "Docker," "container," and "image" as interchangeable words.

## Why this matters in real DevOps/platform work

Getting this vocabulary genuinely straight (not just able to recite it) is what lets you reason correctly later - "why did rebuilding not pick up my change," "why does this container have my old code," "why is this process still running after I removed the container" all trace back to which of these four things you were actually thinking about.

## Concepts

```text
Dockerfile
   ↓  (docker build)
image
   ↓  (docker run)
container
   ↓
process
```

* **Image** — a read-only, layered filesystem snapshot plus metadata (what to run, as whom, on what port). It is not running anything. You can have one image and start ten containers from it.
* **Container** — a running (or stopped) *instance* of an image: the image's filesystem plus a thin writable layer on top, plus an isolated process tree, network namespace, etc. Stop it, and it still exists (just not running) until you remove it.
* **Process** — the actual thing executing inside a running container - in this project's case, the `uvicorn` process your `CMD` starts. A container without a running process is just a stopped, inert filesystem.
* **Registry** — a server that stores and serves images by name and tag (Docker Hub, GitHub Container Registry, a private registry). `docker pull`/`docker push` talk to a registry. This project doesn't push anywhere yet - that's a later stage.

## Investigation steps

You don't have a built image yet, so investigate the vocabulary conceptually for now - you'll come back to this with real commands in Lesson 04.

## Questions for the learner

1. If you `docker run` the same image three times, how many containers do you have? How many images?
2. If you `docker stop` a container, is the image still there? Is the container still there? Is the process still there?
3. Where does a registry fit in this chain - is it closer to "image" or to "container"?

## Practical exercise

Draw (text or on paper) the four-box diagram above from memory, and add one more box before "Dockerfile": what do *you* call the thing that produces the Dockerfile in the first place? (There's no single right answer - this is just making sure "source code" has a place in your mental model too.)

## Verification / checkpoint

You should be able to say, without hesitation: "an image is a template, a container is a running (or stopped) instance of that template, and the registry is where images are stored and shared." If any of those three feel shaky, re-read this lesson before continuing - Lesson 04 assumes you have this cold.

## Recap

You now have the four-word vocabulary - image, container, process, registry - that every remaining lesson in this track builds on. Next: what actually makes up an image internally (layers), which explains a lot of *why* Dockerfiles are written the way they are.
