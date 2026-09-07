# Lesson 02 — Images, Containers, and Layers

**What you'll learn:** why Docker images are built from stacked layers, and why that fact drives almost every Dockerfile-writing decision in this track.

## Goal

Understand what a "layer" is, and why instruction *order* in a Dockerfile is a real engineering decision rather than a stylistic one.

## Why this matters in real DevOps/platform work

Nearly every "best practice" you'll see for writing Dockerfiles - copy dependency files before source code, combine related `RUN` commands, order instructions from least-to-most frequently changing - is a direct consequence of how layers and the build cache work. Understand layers, and those "best practices" stop being rules to memorise and become obvious.

## Concepts

* **Layer** — each instruction in a Dockerfile that changes the filesystem (`RUN`, `COPY`, `ADD`) produces one immutable, content-addressed layer. An image is just an ordered stack of these layers plus metadata.
* **Build cache** — Docker caches each layer by the instruction and its inputs. If an earlier layer is unchanged, Docker reuses its cached result instead of rebuilding it - but the moment one layer's inputs change, every layer *after* it must be rebuilt too, cache or not.
* **Union filesystem** — at runtime, a container sees all of an image's layers merged together as one filesystem, with a thin writable layer added on top for the running container itself.

## Investigation steps

You'll prove this concept with a real rebuild-timing experiment once you have a working Dockerfile (Lesson 06 does exactly this after dependency locking is in place). For now, focus on the concept:

Consider this instruction order:

```dockerfile
COPY . .
RUN pip install .
```

versus:

```dockerfile
COPY pyproject.toml requirements.txt ./
RUN pip install --require-hashes -r requirements.txt
COPY app ./app
RUN pip install --no-deps .
```

## Questions for the learner

1. In the first version, if you change one line in `app/main.py` and rebuild, does the `RUN pip install .` layer get reused from cache, or rebuilt from scratch? Why?
2. In the second version, does that same one-line change in `app/main.py` force the (slow) dependency-install layer to rerun?
3. Which of the two orderings would you expect to rebuild faster, over and over, while actively developing? Why?

## Practical exercise

Without running anything yet, sketch the layer stack (as a simple numbered list, bottom to top) that the second Dockerfile snippet above would produce, and mark which layer(s) would need to be rebuilt if you changed a line in `requirements.txt` versus a line in `app/main.py`.

## Verification / checkpoint

You should be able to explain, in your own words, why `COPY . .` followed immediately by a dependency install is a caching antipattern - not because it's "wrong" syntactically, but because of what it does to the build cache on every single source-code change.

## Recap

An image is a stack of cached layers, and instruction order determines which of those layers survive a rebuild. This is the single idea behind most of the Dockerfile improvements later in this track. Next: choosing what to build *on top of* - the base image.
