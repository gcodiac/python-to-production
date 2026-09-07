# Lesson 13 — Running the Same Image on SQLite or PostgreSQL

**What you'll learn:** how to give a single application image two completely different runtime topologies, why Compose service names work as hostnames, and why "the container is running" is not the same claim as "the database is ready".

## Goal

Run the *same* `notes-app` image two ways — against a SQLite file and against a real PostgreSQL server — using only Compose configuration, and prove to yourself that the application binary you shipped is identical in both cases.

## Why this matters in real DevOps/platform work

The application became database-agnostic back in the DevOps track ([devops-learning/12](../devops-learning/12-designing-for-database-portability.md)). That was a source-code property. This lesson turns it into an *operational* one: two documented, working local topologies a developer can choose between depending on what they're doing today.

That choice matters more than it first appears. If the only way to run the app locally is SQLite, then the first time anyone exercises the PostgreSQL path is in a deployed environment, where a connection problem is entangled with networking, DNS, secrets, and firewalls. If instead PostgreSQL is one command away on a laptop, that entire class of problem gets found somewhere it's cheap to fix.

And the reverse matters too: forcing every developer to run PostgreSQL for every trivial change is a real cost — a slower test suite, another service to keep alive, another thing to break on a plane. Both modes exist because both are genuinely useful.

## Concepts

* **Runtime topology** — the set of processes that run together and how they're wired. The image doesn't change between the two modes here; the topology does.
* **Compose service discovery** — Compose puts services on a shared network with an embedded DNS server, so a service named `postgres` is reachable at the hostname `postgres` from any other service in that file.
* **`localhost` inside a container** — refers to *that container*, not to your machine and not to other containers. This trips up nearly everyone once.
* **Health check vs. liveness of a process** — PostgreSQL spends its first seconds initialising a data directory. The process exists; connections are refused. `pg_isready` asks the real question.
* **`depends_on` with `condition: service_healthy`** — start ordering based on a health check rather than on container creation.
* **Embedded vs. client/server storage** — SQLite is a file this app opens; PostgreSQL is a separate server it connects to over TCP. That difference is the whole reason the second topology needs a network, a health check, and a password.

## Investigation steps

### 1. Read both Compose files side by side

```bash
diff <(grep -v '^\s*#' compose.yaml) <(grep -v '^\s*#' compose.postgres.yaml)
```

Look at how few lines genuinely differ, and note that `build:` and `image:` are not among them.

### 2. Build once

```bash
docker compose build
docker image inspect notes-app:local --format '{{.Id}}'
```

Write that image ID down. It should not change for the rest of this lesson.

### 3. Run mode A — SQLite

```bash
docker compose up -d
docker compose ps
curl -s http://127.0.0.1:8000/ready
```

### 4. Create a note, then destroy and recreate the container

```bash
curl -s -X POST http://127.0.0.1:8000/notes \
  -H 'Content-Type: application/json' \
  -d '{"title":"sqlite mode","content":"lives in the notes-data volume"}'

docker compose down          # removes the container, NOT the volume
docker compose up -d
sleep 5
curl -s http://127.0.0.1:8000/notes
```

### 5. Switch to mode B — PostgreSQL

```bash
docker compose down
docker compose -f compose.postgres.yaml up -d --build
docker compose -f compose.postgres.yaml ps
```

Watch the start-up output: the application container does not start until the `postgres` service reports healthy.

### 6. Confirm which database the application actually reached

```bash
curl -s http://127.0.0.1:8000/ready
```

### 7. Prove it, rather than believing it

A `postgres` container existing next to your app proves nothing on its own. Ask the database directly:

```bash
curl -s -X POST http://127.0.0.1:8000/notes \
  -H 'Content-Type: application/json' \
  -d '{"title":"postgres mode","content":"lives in the postgres-data volume"}'

docker compose -f compose.postgres.yaml exec postgres \
  psql -U notes -d notes -c 'SELECT id, title FROM notes;'
```

### 8. Recreate the database container, keeping its volume

```bash
docker compose -f compose.postgres.yaml rm -sf postgres
docker compose -f compose.postgres.yaml up -d
sleep 10
curl -s http://127.0.0.1:8000/notes
```

### 9. Check the image ID again

```bash
docker image inspect notes-app:local --format '{{.Id}}'
```

## Questions for the learner

1. `compose.postgres.yaml` sets the database host to `postgres`, not `localhost` or an IP address. Where does that name come from, and what would happen if you changed it to `localhost`?
2. The `postgres` service has a health check using `pg_isready`. What would go wrong if `depends_on` waited only for the container to *start*?
3. Mode A gives the application container a `/data` volume. Mode B gives it none at all. Why does the application need no volume when PostgreSQL is in use?
4. You created one note in SQLite mode and a different one in PostgreSQL mode. When you switch back to `docker compose up -d`, which note do you see? Why is this the correct behaviour rather than a bug?
5. Was the image ID in step 9 the same as in step 2? What would it mean about the design if it were not?
6. `compose.postgres.yaml` contains a password in plain text. Why is that acceptable here, and what specifically makes it unacceptable in a deployed environment?

## Commands to run

```bash
docker compose build
docker compose up -d && curl -s http://127.0.0.1:8000/ready
docker compose down
docker compose -f compose.postgres.yaml up -d --build
curl -s http://127.0.0.1:8000/ready
docker compose -f compose.postgres.yaml exec postgres psql -U notes -d notes -c 'SELECT id, title FROM notes;'
docker compose -f compose.postgres.yaml down
make postgres-test
```

## Expected observations

`/ready` reports `{"status":"ready","database":"sqlite"}` in mode A and `{"status":"ready","database":"postgresql"}` in mode B, from the same image ID — the application discovered its backend from `DATABASE_URL`, and nothing was rebuilt. `psql` finds the note that was created over HTTP, which is the only evidence that actually proves the application is using PostgreSQL rather than merely running beside it.

The two modes have separate data. `notes-data` holds the SQLite file; `postgres-data` holds PostgreSQL's data directory. Notes created in one do not appear in the other, and both survive their containers being destroyed and recreated.

## Switching between modes safely

Always bring one topology down before starting the other — both publish port 8000 on the host:

```bash
docker compose down                                # stop SQLite mode
docker compose -f compose.postgres.yaml up -d      # start PostgreSQL mode

docker compose -f compose.postgres.yaml down       # stop PostgreSQL mode
docker compose up -d                               # back to SQLite mode
```

Neither `down` deletes data. To *deliberately* throw a mode's data away:

```bash
docker compose down -v                              # deletes notes-data
docker compose -f compose.postgres.yaml down -v     # deletes postgres-data
```

**`-v` is irreversible.** It is also the only way to reset a database that has got into a state you don't want, so it's worth knowing — just never reflexively.

## Portability is not migration

This is the point people most often get wrong.

```text
database portability   the application runs on either backend
database migration     the data moves from one backend to the other
```

This application does the first. It does not do the second, and nothing here pretends otherwise. Switching `DATABASE_URL` points the app at a different, independent database — which will be empty until something writes to it. Moving real data between engines is a separate discipline (schema translation, type mapping, dump/restore tooling, downtime planning) and deliberately out of scope.

## Why PostgreSQL appears now, before any cloud

Because the alternative is worse. Introducing a new database engine at the same moment as a managed cloud service, a VPC, a secret store and an orchestrator means the first failure has five plausible causes and no way to bisect them. Doing it here, on a laptop, with `docker logs` one command away, means the database question is fully settled before anything else is introduced.

## Practical exercise

Break it on purpose, then read the error:

```bash
docker compose -f compose.postgres.yaml up -d
docker compose -f compose.postgres.yaml stop postgres
curl -i http://127.0.0.1:8000/health
curl -i http://127.0.0.1:8000/ready
```

Note carefully which endpoint still returns `200` and which returns `503`, and write down why that difference is deliberate rather than an inconsistency. Then bring PostgreSQL back up and watch the application recover without being restarted.

## Verification / checkpoint

You should be able to state: the exact command for each local mode, which named volume belongs to which mode, one piece of evidence that proves the application really used PostgreSQL, and why the same image ID appearing in both modes is the whole point rather than a coincidence.

## Recap

You now have two working local topologies built from one image, and you've proven — not assumed — which database each one used. The next lessons return to the image itself: linting it, inspecting it, scanning it, and building the release gate that will check *both* of these modes before any artefact is considered releasable.
