# Lesson 10 — RDS PostgreSQL and Persistent Data

**What you'll learn:** why the cloud environment swaps SQLite for PostgreSQL, how the same codebase supports both, and how the credential never touches Terraform state.

## Goal

Explain the two-backend design in `app/database.py` and the RDS settings chosen for a cost-controlled sandbox.

## Why not SQLite in the cloud?

SQLite is a file. In Kubernetes, a Pod's filesystem is ephemeral — delete the Pod and the file goes with it. Stage 2 solved this locally with a Docker volume, but that only works because the container always lands on the same machine. In a cluster, a Pod can be rescheduled to a different node entirely.

```text
Pod       = replaceable
RDS       = persistent state
```

## One codebase, two backends

Local development keeps SQLite. Cloud staging uses PostgreSQL. **Nothing about the image changes** — only configuration:

```text
LOCAL                              CLOUD
DATABASE_URL=sqlite:///./notes.db  DB_HOST=...rds.amazonaws.com
                                   DB_PORT=5432
                                   DB_NAME=notes
                                   DB_USER=notes_admin
                                   DB_PASSWORD_FILE=/mnt/secrets/db_password
```

```bash
grep -A6 "DB_BACKEND" ../app/config.py
```

`DB_BACKEND` is `postgres` whenever `DB_HOST` is set, otherwise `sqlite`. The SQLite path is byte-for-byte what Stages 1-3 shipped.

## The adapter, and the one place the backends genuinely differ

```bash
grep -A20 "_PostgresConnection" ../app/database.py
```

The application's SQL is written once, using SQLite's `?` placeholders. A thin adapter translates `?` to psycopg's `%s` and returns dict-like rows, so `dict(row)` behaves identically on both.

Only **insert** needed a real branch, because the backends genuinely differ:

* SQLite: `cursor.lastrowid`
* PostgreSQL: `INSERT ... RETURNING *`

```bash
grep -A20 "def insert_note" ../app/database.py
```

That is the honest amount of divergence — not a rewritten data layer.

## Connecting safely

```bash
grep -A20 "_connect_postgres" ../app/database.py
```

Note what is *not* there: any string-built connection URL. Credentials are passed as **keyword arguments**, so a password containing `@`, `:`, `/` or `#` needs no escaping and cannot corrupt the connection parameters. This was verified against a real PostgreSQL container using the deliberately hostile password `p@ss:w/rd#123`.

`sslmode=require` encrypts the connection to RDS. That encrypts traffic but does **not** verify the server's certificate chain — production should consider `verify-full` with the RDS CA bundle, which additionally protects against an impersonated endpoint. That is a genuine gap, stated rather than hidden.

## The RDS configuration

```bash
grep -A30 'resource "aws_db_instance"' ../infra/modules/database/main.tf
```

| Setting | Value | Why |
|---|---|---|
| Engine | PostgreSQL 17.11 | current, mature, well-supported by psycopg |
| Class | `db.t4g.micro` | smallest sensible; $0.017/hour |
| Storage | 20 GiB gp3, **encrypted** | small, autoscaling to 50 GiB |
| `publicly_accessible` | **false** | plus isolated subnets with no internet route |
| `multi_az` | **false** | Multi-AZ roughly doubles instance cost |
| Backups | 3 days | short but deliberately non-zero |
| Performance Insights / Enhanced Monitoring | **off** | both bill extra; Stage 5 uses Prometheus |
| `deletion_protection` | **false** | so this sandbox can actually be torn down |

Production would flip Multi-AZ, deletion protection, and backup retention, and would likely enable Performance Insights.

## The credential never enters Terraform state

```bash
grep -B3 -A3 "manage_master_user_password" ../infra/modules/database/main.tf
```

`manage_master_user_password = true` makes **RDS** generate the password directly into Secrets Manager. Terraform never receives the value, so it cannot appear in state or in a plan file.

Compare with the common tutorial pattern:

```hcl
resource "random_password" "db" { length = 32 }   # now in state, forever
```

### One honest caveat

The application connects as the RDS **master user**. That is acceptable for a disposable sandbox, but production should create a dedicated least-privilege database role (able to read/write the `notes` table and nothing else) rather than letting the application hold master credentials.

## Network path

```bash
grep -A10 "aws_vpc_security_group_ingress_rule" ../infra/modules/database/main.tf
```

Exactly one ingress rule: TCP 5432, from the EKS cluster security group. No `0.0.0.0/0`, no "temporarily open it to debug".

## Questions for the learner

1. Why does a Pod being rescheduled to another node break SQLite-on-a-volume but not RDS?
2. What is the practical difference between `sslmode=require` and `verify-full`?
3. Name two things `manage_master_user_password = true` prevents that `random_password` does not.

## Recap

The same image runs on SQLite locally and PostgreSQL in the cloud, chosen purely by configuration, with a password that RDS generates straight into Secrets Manager and Terraform never sees. Next: how that password reaches the Pod.
