# Lesson 03 — Security and Dependency Gates

**What you'll learn:** the difference between `pip-audit` and Bandit in this pipeline, and why both, plus a code-quality tool (Ruff), are all part of the *same* job rather than three separate ones.

## Goal

Explain precisely what each of Ruff, Bandit, and `pip-audit` catches in `pr-checks.yml`'s first job, using Stage 1 and Stage 2's own tooling-category lessons.

## Why this matters in real DevOps/platform work

By this point in the whole course, you've seen this same "different tools check different things" lesson three times: Ruff vs. SonarQube (Stage 1), Hadolint's limited rule set (Stage 2), and now here, automated. Recognising *which category* a CI failure belongs to is what lets you fix it correctly instead of guessing.

## Concepts, reapplied

```text
Ruff        -> Python lint / code quality
Bandit      -> Python security patterns in OUR source
pip-audit   -> known CVEs in our RESOLVED dependencies
```

All three run in the same `quality-and-security` job, in that order, because they're all cheap, source-only checks with no Docker build involved - see Lesson 01's fail-fast reasoning. Grouping them isn't about them being "the same kind of check" (they aren't); it's about them being similarly *fast*.

## Investigation steps

### 1. Read the actual step order

```bash
sed -n '/quality-and-security:/,/^  dockerfile-lint:/p' .github/workflows/pr-checks.yml
```

### 2. Confirm this is exactly Stage 2's own gate, unchanged

```bash
grep -A3 "^security:\|^audit:\|^lint:" Makefile
```

## Questions for the learner

1. If `pip-audit` found a real vulnerable dependency tomorrow, would Ruff or Bandit catch it too? Why or why not - reconnect to what each tool is actually looking at.
2. This job installs the project with `pip install -e ".[dev]" pip-audit` - notice `pip-audit` isn't in `requirements-dev.txt`. Why might a CI-only tool like this reasonably be installed ad-hoc in the workflow rather than added to the project's own locked dev dependencies?
3. Lesson 02 covered a real Bandit severity-threshold failure. Would a similar issue exist for `pip-audit`, if it found a low-severity/informational-only finding? Check `pip-audit --help` for a comparable severity or exit-code control, and note whether this project currently has any dependency findings to worry about (see `SECURITY.md`).

## Practical exercise

Run all three commands exactly as CI does, in order, locally:

```bash
ruff check app/
pytest
bandit -r app/ --severity-level medium
pip-audit -r requirements.txt
pip-audit -r requirements-dev.txt
```

Confirm every one exits `0` - this is precisely what the `quality-and-security` job checks, and precisely what you should expect to see green before ever pushing.

## Verification / checkpoint

You should be able to state which of the three tools would catch each of these, without running anything: (a) an unused import, (b) a hardcoded secret string, (c) a known-CVE version of `fastapi`.

## Recap

Three tools, three distinct jobs, one fast job in CI - because "fast" and "different concerns" aren't in tension here. Next: what happens once source-level checks pass and a real container needs building.
