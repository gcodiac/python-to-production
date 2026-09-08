# Lesson 10 — RDS PostgreSQL and Persistent Data

**What you'll learn:** why the cloud environment needs a managed database, how much of the application had to change to get one (spoiler: nothing), and how the credential never touches Terraform state.

## Goal

Be able to state exactly which configuration values differ between local PostgreSQL and RDS, and to justify the RDS settings chosen for a cost-controlled sandbox.

## Why not SQLite in the cloud?

SQLite is a file. In Kubernetes, a Pod's filesystem is ephemeral — delete the Pod and the file goes with it. Stage 2 solved this locally with a Docker volume, but that only works because the container always lands on the same machine. In a cluster, a Pod can be rescheduled to a different node entirely, and more than one replica may run at once — which a single-writer file database cannot serve.

```text
Pod       = replaceable
RDS       = persistent state
```

This is not a claim that SQLite is bad. It is a claim about *this* runtime: replicas, rescheduling, and shared state are the requirements, and a file on a Pod's disk does not meet them.

## The interesting part: nothing in the application changed

This is the lesson's real content, and it is deliberately anticlimactic.

```bash
git diff --stat devops/03-cicd..devops/04-cloud-infrastructure -- ../app/ ../tests/ ../pyproject.toml ../requirements.txt
```

That command prints nothing. **The entire cloud stage contains zero changes to application code, tests, or dependencies.**

That is the payoff for work done three stages ago. The application became database-agnostic in Stage 1, developers have been running it on PostgreSQL locally since Stage 2, and CI has been proving both backends work since Stage 3. By the time RDS appears, PostgreSQL is not a new capability — it is a backend this application has been exercising continuously. RDS is a *different address*, not a different application.

Compare the two ways this migration could have gone:

```text
THE COMMON WAY                          THIS COURSE
cloud deadline arrives                  Stage 1: app made portable
      ↓                                        ↓
add PostgreSQL driver                   Stage 2: developers run both locally
      ↓                                        ↓
rewrite the data layer                  Stage 3: CI verifies both
      ↓                                        ↓
debug it against a database             Stage 4: point at RDS
you cannot see, inside a VPC                   ↓
you just built, with secrets            done
you just configured
```

When something *does* go wrong in this stage, it is therefore a networking, IAM, or secrets problem — never an "does our code even work on PostgreSQL" problem. That is worth a great deal at three in the morning.

## Local PostgreSQL → RDS: what actually differs

The application reads its database configuration exactly the same way in all three environments:

```text
LOCAL SQLITE                LOCAL POSTGRESQL              AWS STAGING
DATABASE_URL=               DATABASE_URL=                 DB_HOST=...rds.amazonaws.com
  sqlite:///./notes.db        postgresql+psycopg://       DB_PORT=5432
                              notes:...@postgres:5432/    DB_NAME=notes
                              notes                       DB_USER=notes_admin
                                                          DB_PASSWORD_FILE=
                                                            /mnt/secrets/db_password
```

| | Local PostgreSQL (Compose) | AWS staging (RDS) |
|---|---|---|
| Database engine | PostgreSQL 17.6 | PostgreSQL 17.11 |
| Application code | same | same |
| Container image | same | same |
| Python driver | psycopg 3 | psycopg 3 |
| SQLAlchemy engine/config | same | same |
| Schema creation | `metadata.create_all()` | `metadata.create_all()` |
| DB host | `postgres` (Compose DNS) | RDS endpoint (Route 53 private DNS) |
| DB port | 5432 | 5432 |
| Database name | `notes` | `notes` |
| Credentials from | `.env` / Compose defaults | Secrets Manager, via a mounted file |
| Password reaches app as | environment variable | file at `DB_PASSWORD_FILE` |
| Persistence | Docker named volume | RDS storage (EBS, snapshotted) |
| Backups | none (throwaway) | managed, automated |
| Networking | Compose bridge network | VPC, isolated subnets, security groups |
| TLS | optional, usually off | `sslmode=require` |
| Failure of the DB | `docker compose up` again | AWS handles hardware; you handle config |

Read that table column by column. Everything above the "DB host" row is *identical*, and everything below it is infrastructure. That split is the entire point of the design.

```bash
grep -n "DB_" ../k8s/values/staging.yaml
```

Note which values staging sets explicitly: `DB_PORT`, `DB_NAME`, and `DB_SSLMODE: require`. The application defaults `DB_SSLMODE` to unset, because whether the network between app and database is trusted is a property of the environment, not of the code — so staging states it, and Compose does not.

## How the URL gets built without a URL

The application prefers `DATABASE_URL` when it is set. Staging does not set it, and that is deliberate: embedding the password in a URL means whatever assembles that URL must handle the password, which in Kubernetes would mean putting it in a ConfigMap, a Helm value, or an env var.

```bash
grep -A20 "def database_url" ../app/config.py
```

Instead, staging supplies the components, and the password arrives separately as a file. SQLAlchemy's `URL.create()` assembles them, escaping each part — so an RDS-generated password containing `@`, `:`, `/` or `#` cannot corrupt the connection details, a real bug class that naive f-string URL building introduces.

```bash
grep -A12 "def read_db_password" ../app/config.py
```

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
| Backups | 1 day | the maximum AWS Free Tier allows; production would raise this |
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
4. Staging supplies `DB_HOST`/`DB_USER`/`DB_PASSWORD_FILE` rather than a single `DATABASE_URL`. Give the specific security reason, then give one situation where `DATABASE_URL` would be the better choice.
5. Run the `git diff --stat` command from the top of this lesson. Given that it prints nothing, what work made that possible, and in which stage was it done?
6. Suppose PostgreSQL support had been added *here*, in Stage 4, instead. Name three distinct causes you would have to rule out for a connection failure that you do not have to rule out now.

## Recap

Moving to a managed database turned out to be an infrastructure change and nothing else: same image, same code, same driver, same SQLAlchemy engine — a different host, and a password delivered as a file instead of an environment variable. RDS generates that password straight into Secrets Manager, so Terraform never sees it. Next: how it reaches the Pod.
