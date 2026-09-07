# Lesson 04 — Terraform State and Bootstrap

**What you'll learn:** why Terraform needs state, the chicken-and-egg problem of storing it in S3, and why this project has no DynamoDB table.

## Goal

Understand `infra/bootstrap/` and be able to explain what would break without remote state.

## Why state exists

Terraform records what it created in a **state file** mapping configuration to real resource IDs. Without it, Terraform has no idea that `aws_eks_cluster.this` in your config is the cluster `notes-app-staging` in AWS — so it would try to create it again.

## Why remote state

Local state means: one machine, no collaboration, and total loss if the laptop dies. Remote state in S3 gives durability, sharing and versioning.

## The bootstrap problem

```text
Terraform needs a bucket to store state
        ↓
but creating that bucket is itself Terraform work
        ↓
whose state needs somewhere to live
        ↓
bootstrap problem
```

The resolution used here:

1. `infra/bootstrap` runs first with **local state** and creates the bucket.
2. Its backend block is then enabled.
3. `terraform init -migrate-state` moves the bootstrap's own state into the bucket it just created.

```bash
git show $(git log --oneline --all --grep="Migrate bootstrap state" -1 --format=%h)
```

After that, the bucket contains the state describing the bucket itself — which is exactly why `force_destroy = false` and why teardown treats it separately (Lesson 17).

## What the bucket has, and why

```bash
sed -n '/resource "aws_s3_bucket"/,$p' ../infra/bootstrap/main.tf
```

* **Versioning** — the real safety net; a corrupted state file can be rolled back to a previous object version.
* **Encryption (SSE-S3)** — state can contain sensitive values.
* **Public access block + bucket-owner-enforced ownership** — state must never be public.
* **Lifecycle rule** — expires non-current versions after 90 days so the bucket does not grow forever.

## S3-native locking, not DynamoDB

Two people running `apply` at once can corrupt state, so Terraform takes a lock. Most older tutorials create a DynamoDB table for this. This project does not:

```hcl
backend "s3" {
  bucket       = "notes-app-tfstate-042724764568-eu-west-1"
  key          = "environments/staging/terraform.tfstate"
  region       = "eu-west-1"
  encrypt      = true
  use_lockfile = true     # S3-native locking
}
```

`use_lockfile = true` stores the lock as an object in the same bucket. The DynamoDB approach is **deprecated** in the S3 backend — one less resource, and one less thing to pay for.

## State is sensitive

`.gitignore` excludes `*.tfstate*`, `*.tfplan` and `.terraform/`. `.terraform.lock.hcl` **is** committed — it pins provider versions and hashes, which is a reproducibility feature, not a secret.

This project also deliberately avoids putting the database password into state at all: RDS generates it directly into Secrets Manager (Lesson 10), rather than Terraform generating it with `random_password`.

## Separate state per root

```text
bootstrap/terraform.tfstate            <- the state bucket itself
environments/staging/terraform.tfstate <- AWS infrastructure
platform/staging/terraform.tfstate     <- in-cluster controllers
```

Blast radius: a mistake in the platform root cannot corrupt the state describing the VPC.

## Questions for the learner

1. What would happen on the second `terraform apply` if state were deleted between runs?
2. Why is `.terraform.lock.hcl` committed while `terraform.tfstate` is not?
3. The bucket stores the state that describes the bucket. What does that imply for the order of operations during final teardown?

## Recap

State is Terraform's memory; the bootstrap root solves the ordering problem of storing it remotely, with S3-native locking replacing the legacy DynamoDB table. Next: the network everything runs in.
