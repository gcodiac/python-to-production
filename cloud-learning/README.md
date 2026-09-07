# AWS, Terraform, Kubernetes & EKS

Stage 3 ended with a **trusted container artefact**: built once, scanned, SBOM'd, attested, signed, and verifiable. It just had nowhere to run.

This track gives it somewhere to run — real AWS infrastructure, defined as code, with the application deployed onto Amazon EKS and backed by a managed PostgreSQL database.

```text
trusted artefact
       ↓
cloud infrastructure      (Terraform: VPC, EKS, RDS, ECR, IAM)
       ↓
Kubernetes platform       (Helm: load balancer controller, secrets CSI)
       ↓
deployment                (Helm chart, GitHub OIDC, no stored AWS keys)
       ↓
real running staging service
```

## This is real infrastructure that really costs money

Everything in this track was actually provisioned in a real AWS account in `eu-west-1`, not described hypothetically. That also means it bills by the hour — roughly **$0.21/hour (~$155/month)** while it exists, dominated by the EKS control plane, the worker node, the ALB and RDS.

Lesson 17 covers the full cost breakdown and the teardown procedure, including the ordering trap that orphans a load balancer if you get it wrong.

## Why EKS, when ECS would be simpler

Honestly: for an application this small, **AWS ECS on Fargate would probably be the better engineering choice** — simpler, cheaper to operate, less to maintain. This course deliberately chooses EKS anyway, because the learning objective includes Kubernetes, Helm, controllers, and workload identity — skills that transfer across clouds and on-premises.

Lesson 02 makes that argument properly, including how this same application would be deployed on ECS. It does **not** claim Kubernetes is automatically better.

## One environment, on purpose

Only `staging` is actually built. There is no production environment: a second cluster would roughly double the cost and teach nothing new. Production differences are taught throughout and collected in Lesson 17.

## The Git history is part of the course

```bash
git switch devops/04-cloud-infrastructure
git log --oneline --reverse devops/03-cicd..devops/04-cloud-infrastructure
```

Inspect any step with `git show <commit>`, or check the tree out at that point with `git checkout <commit>` (a detached HEAD — safe to look around). Return with:

```bash
git switch devops/04-cloud-infrastructure
```

## Lessons

| # | Lesson |
|---|--------|
| 00 | [Prerequisites and Safe AWS Access](00-prerequisites-and-safe-aws-access.md) |
| 01 | [From Container to Cloud](01-from-container-to-cloud.md) |
| 02 | [ECS vs EKS: Choosing a Runtime](02-ecs-vs-eks-choosing-a-runtime.md) |
| 03 | [Kubernetes and EKS Mental Model](03-kubernetes-and-eks-mental-model.md) |
| 04 | [Terraform State and Bootstrap](04-terraform-state-and-bootstrap.md) |
| 05 | [VPCs, Subnets, Routing and Security](05-vpcs-subnets-routing-and-security.md) |
| 06 | [Building an EKS Cluster](06-building-an-eks-cluster.md) |
| 07 | [Nodes, Add-ons, Access and Pod Identity](07-nodes-addons-access-and-pod-identity.md) |
| 08 | [Helm and Kubernetes Platform Controllers](08-helm-and-kubernetes-platform-controllers.md) |
| 09 | [ECR and Artifact Promotion](09-ecr-and-artifact-promotion.md) |
| 10 | [RDS PostgreSQL and Persistent Data](10-rds-postgresql-and-persistent-data.md) |
| 11 | [Secrets Manager and Kubernetes Secrets](11-secrets-manager-and-kubernetes-secrets.md) |
| 12 | [Packaging the Application with Helm](12-packaging-the-application-with-helm.md) |
| 13 | [Ingress, Load Balancing and Health](13-ingress-load-balancing-and-health.md) |
| 14 | [Kubernetes Workload Security](14-kubernetes-workload-security.md) |
| 15 | [GitHub OIDC and Kubernetes Deployment](15-github-oidc-and-kubernetes-deployment.md) |
| 16 | [Deploying and Debugging the Real Application](16-deploying-and-debugging-the-real-application.md) |
| 17 | [Costs, Production Trade-offs and Teardown](17-costs-production-tradeoffs-and-teardown.md) |

## What you'll have by the end

A real EKS cluster running the Notes application behind an AWS ALB, storing data in RDS PostgreSQL, reading its database password from Secrets Manager via Pod Identity, deployed by GitHub Actions using OIDC with no stored AWS credentials anywhere — and the ability to explain and debug every layer of it with `kubectl`, `helm` and `terraform`.
