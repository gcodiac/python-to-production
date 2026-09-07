# DevOps / Platform Engineering: Taking Over an Existing Application

Welcome! This track puts you in a very common real-world position: a development team has finished building an application, and it has just landed in your lap. You didn't write it. Nobody has walked you through it. Your job is to get it ready to run reliably outside of one developer's laptop — and *before* you're allowed to touch Docker, you need to actually understand what you've been given.

This track uses the exact Notes API application in this repository (`app/`) as the "application you've inherited." It has been deliberately built the way real handed-over applications often are: it works, it has tests, and it also has a small, realistic set of code-quality and configuration problems hiding in it. Finding those problems yourself is part of the exercise.

## Is this track for you?

This track assumes you're comfortable with basic programming and ideally have been through the [learning/](../learning/) FastAPI course (or already know roughly what FastAPI/SQLite/pytest are). You do **not** need any prior DevOps, Linux, or cloud experience — every command you need is introduced as you go.

## How this track is different from the FastAPI course

The [learning/](../learning/) track teaches you to **build** this application, lesson by lesson, typing out the code yourself.

This track teaches you to **receive** this application as a stranger would, and get it ready for the next stage of its life — static analysis, security scanning, configuration management, and eventually containers and CI/CD (in a later track). You will read a lot more code than you write, and several lessons deliberately ask you to investigate before they tell you the answer.

## A note on honesty

Real handed-over codebases have real problems, and so does this one — on purpose. Every problem that was **deliberately** planted for you to find is marked in the source with a comment containing the tag `TRAINING-ISSUE`. You will be asked to find these using proper tooling rather than just grepping for the tag on day one — treat it the way you'd treat any other inherited codebase, where nobody hands you a list of what's broken. The tag exists so that once you've found something, you can confirm you found a *real, intended* issue and not just a stylistic choice you disagree with.

## The workflow this track follows

```text
Receive application
        ↓
Understand application
        ↓
Run application
        ↓
Run tests
        ↓
Static analysis
        ↓
Security analysis
        ↓
Identify configuration problems
        ↓
Externalise configuration
        ↓
Improve operational readiness
        ↓
Containerise   <- a later track picks up here
```

This track covers everything down to "improve operational readiness." Containerisation, CI/CD, and cloud deployment are deliberately left for the track that follows this one — see [13-ready-for-containers.md](13-ready-for-containers.md) for why.

## Lessons

| # | Lesson |
|---|--------|
| 00 | [You Have Been Handed an Application](00-you-have-been-handed-an-application.md) |
| 01 | [Understanding the Application](01-understanding-the-application.md) |
| 02 | [Mapping the Architecture](02-mapping-the-architecture.md) |
| 03 | [Running the Application Locally](03-running-the-application-locally.md) |
| 04 | [Understanding Dependencies and Runtime](04-understanding-dependencies-and-runtime.md) |
| 05 | [Static Code Analysis](05-static-code-analysis.md) |
| 06 | [Security Scanning](06-security-scanning.md) |
| 07 | [Finding Hard-Coded Configuration](07-finding-hard-coded-configuration.md) |
| 08 | [Environment Variables and dotenv](08-environment-variables-and-dotenv.md) |
| 09 | [Configuration for Different Environments](09-configuration-for-different-environments.md) |
| 10 | [Logging and Operational Readiness](10-logging-and-operational-readiness.md) |
| 11 | [Health Checks and Service Readiness](11-health-checks-and-service-readiness.md) |
| 12 | [Pre-Containerisation Review](12-pre-containerisation-review.md) |
| 13 | [Ready for Containers](13-ready-for-containers.md) |

## What you'll have by the end

A codebase you can genuinely explain to someone else — its structure, its dependencies, its runtime behaviour, its configuration, and its known problems — plus a working `.env`-based configuration setup you built yourself, a completed pre-containerisation checklist, and a clear picture of why each of those things matters before a single `Dockerfile` gets written.
