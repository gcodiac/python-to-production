# Lesson 00 — Prerequisites and Safe AWS Access

**What you'll learn:** how to set up everything this track needs from scratch, and why the AWS access model used here is explicitly *not* how a real organisation should work.

## Goal

Get a working, budget-protected AWS sandbox and the five CLI tools this track uses — and understand the security trade-off you are accepting while you do it.

## Why this matters

This is the first stage that spends real money and touches real cloud credentials. Both deserve deliberate setup rather than copy-paste.

## 1. An AWS account for practice

Use a **dedicated sandbox/practice account**, never an account with anything real in it. Everything in this track is designed to be deleted afterwards.

* Enable **MFA on the root user** immediately, then stop using root for daily work.
* Set a **budget alert** (AWS Budgets → create a monthly cost budget with an email alert at, say, $20 and $50). This does *not* cap spending — it only tells you. There is no hard spending limit in AWS.
* If you have promotional credits: credits are **not** a spending cap either. They offset a bill that keeps growing regardless.

## 2. AWS CLI

```bash
aws --version          # this track used aws-cli/2.36.40
```

Install from the official AWS docs if missing (v2 required).

## 3. A dedicated sandbox IAM user for Terraform

For this disposable sandbox only, create an IAM user with `AdministratorAccess`:

1. IAM → Users → Create user, e.g. `terraform-user`.
2. Attach `AdministratorAccess` **directly** (sandbox only).
3. Create an access key of type "Command Line Interface (CLI)".
4. Configure it locally:

```bash
aws configure          # paste key id + secret, set region eu-west-1, output json
```

Verify:

```bash
aws sts get-caller-identity
aws configure get region     # must print eu-west-1
```

### Be honest about what this is

A long-lived IAM user access key with `AdministratorAccess` is **not** an acceptable production pattern. It is tolerated here because the account is disposable and contains nothing of value. Real organisations should use:

* **IAM Identity Center (SSO)** with short-lived session credentials, or
* **federation** from an existing identity provider, and
* **least-privilege roles** rather than `AdministratorAccess`.

Note also what this track does *not* do with that key: GitHub Actions never receives it. CI authenticates using **OIDC** and receives short-lived credentials instead (Lesson 15) — which is precisely the pattern that should replace this user everywhere.

### Deleting the key afterwards

When you finish the course:

```bash
aws iam list-access-keys --user-name terraform-user
aws iam update-access-key --user-name terraform-user --access-key-id <ID> --status Inactive
aws iam delete-access-key --user-name terraform-user --access-key-id <ID>
```

Deactivate first, confirm nothing breaks, then delete.

### Never do these

Never put AWS keys into Terraform files, `.tfvars`, Git, GitHub secrets, lesson text, or command output. Providers in this repository contain no credentials at all — they use the standard AWS credential chain.

## 4. Terraform

```bash
terraform version      # this track used Terraform v1.16.1
```

## 5. kubectl

```bash
kubectl version --client
```

Install per the official Kubernetes docs. Keep it within one minor version of the cluster — this track runs Kubernetes **1.36**, and was driven with kubectl **1.37**.

## 6. Helm

```bash
helm version           # this track used v4.2.4
```

## 7. Docker

Needed for local container work and by the CI runners. Verify:

```bash
docker version
```

## 8. GitHub CLI

```bash
gh auth status
```

## Verification checkpoint

All of these should succeed before Lesson 04:

```bash
aws sts get-caller-identity
aws configure get region        # eu-west-1
terraform version
kubectl version --client
helm version
docker version
gh auth status
```

## Recap

You have a disposable AWS sandbox with budget alerts, a local admin credential you understand the limitations of, and the tool-chain this track drives. Next: what actually has to exist in the cloud before a container can run there.
