# Lesson 15 — GitHub OIDC and Kubernetes Deployment

**What you'll learn:** how GitHub Actions deploys to AWS with no stored credentials, and why the deploy role is deliberately weak.

## Goal

Explain the trust chain from a workflow run to a `helm upgrade`, and justify each permission boundary.

## The problem with the obvious approach

```text
BAD DEFAULT
long-lived AWS access key  ->  GitHub secret  ->  never rotated, leaks in logs,
                                                  works from anywhere forever
```

## OIDC instead

```text
GitHub Actions job
   ↓ requests an OIDC token describing repo, ref, workflow, actor
token.actions.githubusercontent.com
   ↓
AWS IAM OIDC provider  ->  sts:AssumeRoleWithWebIdentity
   ↓
temporary credentials, scoped to this run, expiring in minutes
```

No secret is stored. Nothing to leak, nothing to rotate.

## The trust policy is where the security lives

```bash
grep -A25 "assume_role_policy" ../infra/modules/identity/main.tf
```

Two conditions, both essential:

* **Audience** (`aud = sts.amazonaws.com`) — the token was minted for AWS STS, not some other service.
* **Subject** (`sub`) — *exactly* which GitHub identities may assume this role:

```bash
grep -A5 "github_subjects" ../infra/environments/staging/main.tf
```

```text
repo:gcodiac/python-to-production:ref:refs/tags/stage4-deploy-*
repo:gcodiac/python-to-production:ref:refs/heads/devops/04-cloud-infrastructure
```

What this deliberately is **not**:

* `repo:*/*` — would trust every repository on GitHub.
* `repo:gcodiac/python-to-production:*` — would trust every branch **and every pull request**, including a PR from a fork containing modified workflow code.

Scoping to specific refs is what stops an untrusted pull request from obtaining AWS credentials.

## The role is intentionally near-powerless

```bash
grep -A30 "data \"aws_iam_policy_document\" \"github_deploy\"" ../infra/modules/identity/main.tf
```

It can: get an ECR auth token, push/pull **this one repository's** images, and `eks:DescribeCluster` on **this one cluster**.

It cannot: create VPCs, create IAM roles, create or delete EKS clusters, touch RDS, or manage any unrelated resource. Notably it also **cannot run `terraform apply`** — infrastructure provisioning remains a deliberate local admin activity in this course.

```text
Terraform plan/apply  =  local, controlled, human-driven
GitHub Actions        =  application deployment only
```

A mature organisation would eventually automate Terraform too, with plan-on-PR and apply-on-merge behind environment approvals — but giving CI broad infrastructure power is a decision to make deliberately, not by default.

## Kubernetes permissions are separate from AWS permissions

Being allowed to `eks:DescribeCluster` gets you a kubeconfig, not authorisation. Kubernetes access is granted separately:

```bash
grep -A12 "aws_eks_access_policy_association" ../infra/modules/eks/main.tf
```

`AmazonEKSEditPolicy`, scoped to the `notes-app` namespace. CI can manage the application's Deployment, Service, Ingress, ConfigMap and SecretProviderClass — and cannot touch `kube-system`, other namespaces, or cluster-scoped objects.

## The workflow

```bash
cat ../.github/workflows/deploy-staging.yml
```

Order matters:

1. Resolve the source digest (must be `sha256:...`).
2. **Verify the Stage 3 signature** before anything AWS-related happens.
3. Assume the AWS role via OIDC.
4. Promote the image to ECR (copy, never rebuild).
5. Read non-secret infrastructure values (endpoint, username, secret ARN — never the password).
6. `helm upgrade --install`.
7. `kubectl rollout status` — because `helm --wait` returning is not proof of a healthy rollout.

Job permissions are minimal: `contents: read`, `id-token: write` (for OIDC), `packages: read` (to pull from GHCR).

## Two workflows, two privilege levels

* `infra-checks.yml` — validation only: `terraform fmt/validate`, tflint, helm lint, kubeconform, Trivy IaC. **No AWS credentials at all**, because static analysis of files needs none.
* `deploy-staging.yml` — the only workflow that touches AWS, and only via OIDC.

## Questions for the learner

1. Why is `repo:owner/name:*` dangerous as a trust subject?
2. The deploy role can `eks:DescribeCluster`. Why is that not enough to deploy anything?
3. Why does `infra-checks.yml` deliberately have no AWS access?

## Recap

CI authenticates with a short-lived, tightly-scoped OIDC identity; its AWS permissions cover only image promotion and cluster discovery; and its Kubernetes permissions stop at one namespace. Next: the real deployment.
