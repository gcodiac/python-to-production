# Lesson 12 — Designing for Database Portability

**What you'll learn:** how to make an application able to run against more than one database without changing a line of its source code — and why that work belongs *here*, long before anyone mentions Docker or a cloud provider.

## Goal

Understand the change that turns "an app that uses SQLite" into "an app that uses whatever database its environment points it at", and be able to run this application against either SQLite or PostgreSQL by editing configuration only.

## Why this matters in real DevOps/platform work

Sooner or later this application will run somewhere that a single file on local disk is the wrong answer: several instances behind a load balancer, a container whose filesystem disappears on restart, a managed database service. The tempting move at that moment is to open `app/database.py` and add a branch — "if we're in the cloud, use PostgreSQL". That is the beginning of a codebase where nobody can predict what the application does without knowing where it is running.

The alternative is to do the portability work *now*, while the application is still small and there is no deployment deadline attached to it. Then the cloud migration, when it happens, is a configuration change and nothing more.

There is a second reason this belongs early. If PostgreSQL support first appears at the same moment the cloud infrastructure does, then the first time anyone runs the application against PostgreSQL is also the first time they run it against a database they cannot see, inside a network they have just built, using credentials from a secret store they have just configured. When it fails — and it will — there are five candidate causes. Introducing the database change on its own, locally, means it gets debugged on its own.

## Concepts

* **Database driver vs. database server** — `psycopg` is a Python library that speaks PostgreSQL's wire protocol. It is not PostgreSQL. Installing it lets your application *talk to* a PostgreSQL server; it does not give you one.
* **SQLAlchemy** — a Python library that sits between application code and a database driver. Its Core layer lets you express queries as Python objects that it renders into the dialect of whichever database is connected.
* **Database URL** — a single string that says which engine, which driver, which host, and which database: `sqlite:///./notes.db`, or `postgresql+psycopg://notes:password@localhost:5432/notes`.
* **Dialect** — the ways real SQL databases differ: `AUTOINCREMENT` versus `GENERATED ALWAYS AS IDENTITY`, `?` versus `%s` placeholders, `datetime('now')` versus `now()`. Portability work is mostly about not hand-writing these.
* **Embedded vs. client/server database** — SQLite runs *inside* your process and stores data in a file. PostgreSQL is a separate program you connect to over a network socket. This difference is the source of nearly every behavioural difference between the two.

## Investigation steps

### 1. Look at how the application decides where its data lives

```bash
sed -n '/--- Database configuration/,/^APP_SECRET/p' app/config.py
```

Read the precedence comment carefully. There are exactly three possibilities, in a fixed order.

### 2. Find the only place that cares which database is in use

```bash
grep -n "get_backend_name\|sqlite" app/database.py
```

There should be very little. Note *why* the one real branch exists.

### 3. Confirm the application code itself is backend-neutral

```bash
grep -n "SELECT\|INSERT\|UPDATE\|DELETE" app/main.py
```

### 4. Prove both backends are actually reachable from configuration

```bash
pytest tests/test_database_config.py -v
```

These tests never open a connection, so they pass without a PostgreSQL server running anywhere.

### 5. Run the application on SQLite, exactly as before

```bash
cp .env.example .env
uvicorn app.main:app --reload &
curl -s http://127.0.0.1:8000/ready
```

## Questions for the learner

1. `/ready` reports which backend it just talked to. Where does that value come from — configuration, or a hard-coded default in the source?
2. `app/database.py` sets `check_same_thread: False`, but only for SQLite. What would happen if that option were passed to psycopg instead? Why is *this* branch acceptable when "if cloud: use_postgres()" is not?
3. The `created_at` column gets its default value from Python rather than from the database. What would have to be written twice if the database supplied it instead?
4. `config.database_url()` builds a URL with `URL.create()` rather than an f-string. Write down what the resulting URL would look like if the password were `p@ssw0rd` and the code had used an f-string instead. Which host would the application try to connect to?
5. If `DB_HOST` is set but no password can be found, the application raises an error instead of falling back to SQLite. Why is falling back the more dangerous behaviour?

## Commands to run

```bash
sed -n '/--- Database configuration/,/^APP_SECRET/p' app/config.py
grep -n "get_backend_name\|sqlite" app/database.py
pytest tests/test_database_config.py -v
python -c "from app.database import engine_options; print(engine_options('sqlite:///./notes.db'))"
python -c "from app.database import engine_options; print(engine_options('postgresql+psycopg://u:p@h/notes'))"
```

## Expected observations

`app/main.py` contains no SQL text at all — every query is built from the `notes` table object, so there is nothing for a dialect difference to break. `app/database.py` inspects the backend in exactly one function, `engine_options()`, and does so only to decide whether SQLite's `check_same_thread` override applies; the two `engine_options()` commands above print a dict *with* `connect_args` for SQLite and *without* it for PostgreSQL. Configuration precedence is `DATABASE_URL`, then the `DB_*` components, then a local SQLite default — so a developer who sets nothing at all still gets a working application, and a deployment that sets `DB_HOST` without a password gets a loud error rather than a silent, empty local database.

## SQLite is not a mistake

It would be easy to read this lesson as "SQLite was wrong and PostgreSQL is right". That is not the lesson.

| | SQLite | PostgreSQL |
|---|---|---|
| Where it runs | inside your process | a separate server |
| Setup cost | none | install/run a server |
| Concurrent writers | one at a time | many |
| Multiple app instances | not sensibly | yes |
| Test suite speed | very fast | slower |
| Works offline on a plane | yes | only if you run a server locally |

SQLite is an excellent choice for local development, for this application's test suite, and for plenty of real production systems that will never need a second writer. PostgreSQL is the right choice when several application instances must share state, which is exactly what happens once this app is deployed behind a load balancer.

The engineering goal is not "use the production database everywhere". It is **being able to choose**, per environment, without touching the code. A developer who wants the fast path keeps SQLite; a developer chasing a bug that only appears on PostgreSQL switches with one environment variable.

## Practical exercise

Without installing PostgreSQL, prove to yourself that the application would use it if told to:

```bash
DATABASE_URL="postgresql+psycopg://notes:whatever@127.0.0.1:5432/notes" \
  python -c "from app.database import create_database_engine; e = create_database_engine(); print(e.dialect.name, e.dialect.driver)"
```

This builds a real PostgreSQL engine — which requires the driver to be installed and importable — without connecting to anything. Then try it with a deliberately wrong driver name (`postgresql+nosuchdriver://...`) and read the error you get.

## Verification / checkpoint

You should be able to answer, without reading the source again: which environment variable switches this application between databases, which single function contains the only backend-specific code in the application, and why the PostgreSQL driver is already installed even though nothing in this track has run a PostgreSQL server yet.

## Recap

You've taken an application that was wired to one specific database and made the database an environment decision rather than a source-code decision. Nothing about this required a container, a cloud account, or a running PostgreSQL server — which is the point. The next track will run this exact application, unmodified, against both SQLite and a real PostgreSQL container; the track after that will have CI verify both on every change; and the cloud track will point it at a managed PostgreSQL service by changing configuration and nothing else.
