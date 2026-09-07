# Infrastructure

Terraform for the Notes application's AWS staging environment. See the
[cloud-learning/](../cloud-learning/) track for the teaching material that
explains every decision here.

## Layout

```text
infra/
├── bootstrap/            # S3 remote-state bucket (runs once, with local state first)
├── modules/
│   ├── network/          # VPC, subnets, IGW, routing
│   ├── eks/              # cluster, node group, add-ons, access entries
│   ├── database/         # RDS PostgreSQL + Secrets Manager
│   └── identity/         # GitHub OIDC provider + deployment role
├── environments/
│   └── staging/          # the one real environment this course provisions
└── platform/
    └── staging/          # in-cluster controllers (Helm), separate from AWS infra
```

## Ownership boundaries

Keeping these separate is what stops Terraform and CI fighting over the same
resources:

| Owner | Owns |
|---|---|
| `infra/environments/staging` | VPC, subnets, routing, EKS cluster, node group, IAM, RDS, ECR, GitHub OIDC |
| `infra/platform/staging` | cluster-level controllers (AWS Load Balancer Controller, Secrets Store CSI), the `notes-app` namespace |
| Helm via GitHub Actions | the Notes application Deployment/Service/Ingress/SecretProviderClass and its release history |

## Order of operations

```bash
# 1. Remote state (once per account)
cd bootstrap
terraform init && terraform apply
# then uncomment the backend block and:
terraform init -migrate-state

# 2. AWS infrastructure
cd ../environments/staging
terraform init && terraform apply

# 3. In-cluster platform controllers
aws eks update-kubeconfig --region eu-west-1 --name notes-app-staging
cd ../../platform/staging
terraform init && terraform apply
```

## State

* Backend: S3, encrypted (SSE-S3), versioned, public access blocked.
* Locking: **S3 native locking** (`use_lockfile = true`). No DynamoDB table -
  that approach is deprecated in the S3 backend, though most older tutorials
  still show it.
* State is sensitive. `.gitignore` excludes `*.tfstate*`, `*.tfplan` and
  `.terraform/`; `.terraform.lock.hcl` **is** committed so provider versions
  and hashes are reproducible.

## Credentials

No AWS keys appear anywhere in this directory. Providers use the normal AWS
credential chain locally, and GitHub Actions uses OIDC to assume a role with
short-lived credentials - never a stored access key.

## Teardown

See [cloud-learning/17-costs-production-tradeoffs-and-teardown.md](../cloud-learning/17-costs-production-tradeoffs-and-teardown.md).
The critical ordering rule: delete the Kubernetes Ingress (so the AWS Load
Balancer Controller removes its ALB) **before** destroying the cluster, or the
ALB is orphaned and keeps billing.
