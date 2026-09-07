# Lesson 00 — You Have Been Handed an Application

**What you'll learn:** how to approach an unfamiliar codebase like a platform engineer, before writing or running a single command.

## The scenario

Imagine you've just joined a small company as a junior DevOps/platform engineer. A development team has been building a small internal tool — a Notes API with a web dashboard — and it now works well enough to hand off. Your manager sends you a link to the repository and says:

> "Can you get this running somewhere reliable? Find out what it needs, tidy up anything obviously wrong, and get it ready for us to containerise."

That's it. That's the whole brief. No architecture diagram, no runbook, no list of known issues. This is completely normal — it's exactly how this kind of handover happens in most small and mid-sized companies. Nobody is going to walk you through the code line by line.

## Why this matters in real DevOps/platform work

Platform and DevOps engineers spend a surprisingly large amount of time working with code they didn't write. Whether it's a new service joining your platform, an application you're migrating to Kubernetes, or a legacy app nobody currently owns, the very first skill you need isn't Docker or Terraform — it's **systematic investigation**. Engineers who skip this step and jump straight to "let's containerise it" routinely discover, too late, that the app hard-codes a database path, binds to the wrong interface, or silently depends on a secret nobody told them about.

## Ground rules for this track

1. **Don't touch application business logic.** Your job is the *engineering around* the app (how it's run, configured, observed, packaged) — not rewriting its features.
2. **Don't jump to Docker.** It's tempting, but you can't containerise what you don't understand. This whole track happens before a `Dockerfile` exists.
3. **Investigate before you conclude.** Several lessons ask you a question and expect you to go find the answer in the code before reading further.
4. **Everything here is Linux/bash-based.** All commands assume a standard Linux terminal.

## Concepts

* **Handover** — the point at which responsibility for running/operating an application passes from the people who built it to the people who run it.
* **Tribal knowledge** — undocumented assumptions the original developers made, which you must uncover rather than be told.
* **Investigation-first workflow** — read → run → test → analyse → configure → operate → (later) containerise. Skipping steps is how outages happen.

## Practical exercise

Before opening a single `.py` file, open a terminal in the project root (`notes-app/`) and just look around, the way you would on your first day:

```bash
cd ~/learning/Projects/python-to-production/fastapi-python/notes-app
ls -la
cat README.md
```

Write down (in a scratch note, notebook, or text file — this isn't graded, it's for you) the answers to these questions, based on the README and directory listing alone, **before** moving to Lesson 01:

1. What does this application appear to do, in one sentence?
2. What programming language and web framework does it use?
3. What does it use for data storage?
4. Is there an existing test suite?
5. Is there more than one "track" of learning material in this repository? What do you think the difference between them is?

## Expected observations

You should have noticed: it's a small Python web API (FastAPI), it stores notes, it appears to use SQLite, there's a `tests/` folder suggesting `pytest` is used, and there are two learning directories — `learning/` (how the app was built) and `devops-learning/` (this one — how to operate it). You don't need to be certain about anything yet; you're forming a hypothesis you'll confirm in the next lesson.

## Verification / checkpoint

You should have a short written list of first impressions and open questions. If you can't answer question 1 in one sentence yet, re-read the README — that's exactly the kind of fast orientation reading a real handover document should give you.

## Recap

You've adopted the mindset of someone receiving an application rather than building one: read first, form hypotheses, and resist the urge to start "fixing" things immediately. Lesson 01 starts turning those first impressions into confirmed facts.
