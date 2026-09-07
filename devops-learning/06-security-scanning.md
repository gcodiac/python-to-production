# Lesson 06 — Security Scanning

**What you'll learn:** running `bandit` against Python source, interpreting severity/confidence, and telling the difference between a secret, configuration, and source code.

## Goal

Run a security-focused static scanner against the application, understand every finding it produces, and clearly identify which parts of the source code are secrets/configuration that should never have been committed in the first place.

## Why this matters in real DevOps/platform work

Security scanning is a distinct discipline from general code quality. A linter cares if code is *messy*; a security scanner cares if code is *dangerous* — hard-coded credentials, unsafe query construction, insecure defaults. Platform engineers are very often the ones who introduce this kind of scanning into a pipeline for the first time on a legacy codebase, and the first run is almost always uncomfortable. Getting good at reading and triaging the results (instead of either ignoring them all or panicking about all of them) is the actual skill.

## Concepts

* **Secret** — a value that grants access or proves identity (a password, API key, token, signing key). Secrets must never live in source code or git history.
* **Configuration** — a value that changes how the app behaves but doesn't grant access on its own (a log level, a port number, a feature flag).
* **Environment-specific configuration** — configuration whose *correct value* depends on where the app is running (a database URL that's `sqlite:///./notes.db` locally but points somewhere else entirely in production).
* **Source code** — the logic itself, which should be identical across every environment. If your source code needs to change to move from staging to production, something is wrong with how configuration is handled — you'll fix exactly this in Lessons 07–09.
* **Severity vs. confidence** — most scanners report *how bad* a finding would be if real (severity) separately from *how sure the tool is* that it's a genuine issue (confidence). Both matter when triaging.

## Investigation steps

### 1. Run Bandit against the application code

```bash
source .venv/bin/activate
bandit -r app/
```

### 2. Read each finding

For each one, Bandit reports an issue ID (e.g. `B105`), a severity, a confidence level, and the exact line.

### 3. For each finding, ask three questions

1. What line of code triggered this?
2. Is this really a **secret**, or is it configuration, or is it neither?
3. Would this finding still exist if the value came from an environment variable instead of being written directly in the file?

### 4. Think about git history

Even if you deleted a hard-coded secret from a file right now, would it be truly gone? Try:

```bash
git log --all -p -- app/main.py | grep -n "APP_SECRET" | head
```

## Questions for the learner

1. Bandit should report a "possible hardcoded password" finding. What variable does it point at? Is it actually a password — or something broader?
2. Bandit should also report something about binding to all network interfaces. Which hard-coded value causes that, and how does it relate to what you discovered about bind addresses back in Lesson 03?
3. Bandit should report a possible SQL injection vector around the note-sorting query in `list_notes`. Open that code. Is user input actually concatenated unsafely into SQL here, or is the risk more subtle? (Hint: look at `_resolve_sort_order` — is `sort` ever used *directly* in the query string, or only used to pick from a fixed set of safe values?) This is a good example of a **low-confidence** finding: worth understanding, not necessarily worth panicking over, but also a pattern worth avoiding, because a future edit to that function could easily turn it into a real vulnerability.
4. Why does `git log -p` still show a secret even after you imagine deleting it from the current file? What does that imply about the correct response to "we accidentally committed a real secret" (hint: it's not "just delete it in the next commit")?

## Commands to run

```bash
bandit -r app/
grep -rn "APP_SECRET\|APP_HOST\|APP_PORT" app/main.py
```

## Expected observations

Bandit reports (at minimum): a hard-coded password/secret-like string assigned to `APP_SECRET`; a bind-all-interfaces warning tied to the hard-coded `"0.0.0.0"` value used in the app's `__main__` block; a possible SQL-injection pattern around the dynamically built sort query; and the same overly broad `except Exception: pass` block you likely already noticed in Lesson 05, which Bandit also flags from a security angle (swallowed exceptions can hide real failures, including security-relevant ones). None of this is a real secret — it's a training placeholder — but a real version of `APP_SECRET` here would already be permanently in your git history the moment it was committed, regardless of what you do to later commits.

## Practical exercise

Write a short table with one row per Bandit finding: **finding**, **file:line**, **is it a secret, configuration, or a code pattern issue?**, **severity**, **confidence**. For the `APP_SECRET` finding specifically, write one sentence explaining why — even though it's clearly labelled as a training placeholder — a real version of this pattern would require rotating the real secret, not just deleting the line.

## Verification / checkpoint

You should be able to name, without looking back at this lesson, which hard-coded value in `app/main.py` is a genuine secret, and explain in your own words why secrets, configuration, and source code need to be treated as three different things.

## Recap

You've run a real security scanner against real code, learned to separate severity from confidence, and drawn a clear line between secrets, configuration, and source code. In the next lesson, you'll go hunting specifically for every piece of hard-coded configuration in this app — using both what the tools told you and your own manual search.
