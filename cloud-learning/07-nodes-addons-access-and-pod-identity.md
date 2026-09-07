# Lesson 07 — Nodes, Add-ons, Access and Pod Identity

**What you'll learn:** managed node groups, node hardening, EKS add-ons, and how a Pod gets AWS permissions without ever holding a key.

## Goal

Explain how the Notes Pod is allowed to read one Secrets Manager secret and nothing else.

## Managed node group

```bash
grep -A20 'resource "aws_eks_node_group"' ../infra/modules/eks/main.tf
```

* **t3.medium** — 2 vCPU / 4 GiB, x86_64 (the application image is amd64 only, so Graviton/ARM instances are not an option without a multi-arch build). $0.0456/hour in eu-west-1.
* **min 1 / desired 1 / max 2** — a deliberate cost ceiling. Nothing autoscales.
* **ON_DEMAND** — predictable for training. Spot is roughly 70% cheaper and excellent for fault-tolerant or non-critical workloads, but instances can be reclaimed at two minutes' notice, which is a poor property for a single-node teaching cluster.

Not used, and taught conceptually only: **Cluster Autoscaler**, **Karpenter**, **EKS Auto Mode**, **EKS Fargate**. Each removes visibility of exactly the mechanics this lesson exists to show.

## Node hardening

```bash
grep -A12 "metadata_options" ../infra/modules/eks/main.tf
```

* **No SSH key, no port 22.** Workloads are managed with `kubectl`, not by logging into servers. If you find yourself wanting SSH, you probably want `kubectl logs`, `kubectl describe` or `kubectl exec`.
* **IMDSv2 required** (`http_tokens = "required"`) — blocks the classic SSRF-to-credential-theft path where a vulnerable app is tricked into reading instance credentials over plain HTTP.
* **Hop limit 1** — metadata is reachable from the node but not from inside a container (whose traffic takes an extra network hop). This is what stops Pods quietly falling back to the *node's* IAM role instead of their own identity.
* **Encrypted gp3 root volume.**
* **Minimal node IAM role** — the three AWS-managed policies a node genuinely needs, and nothing more.

Bottlerocket is a strong production choice (minimal, immutable, container-optimised OS) but is not used here — the default EKS AL2023 AMI keeps the environment closer to what most tutorials and troubleshooting docs assume.

## Add-ons, versioned properly

```bash
grep -A10 'data "aws_eks_addon_version"' ../infra/modules/eks/main.tf
```

Four managed add-ons: **vpc-cni** (Pod networking), **coredns** (in-cluster DNS), **kube-proxy** (Service routing), **eks-pod-identity-agent** (workload identity).

Versions are *discovered* from what AWS reports as the default for this exact Kubernetes version, rather than pasted from a tutorial:

```bash
aws eks describe-addon-versions --addon-name vpc-cni \
  --kubernetes-version 1.36 --region eu-west-1 \
  --query 'addons[0].addonVersions[?compatibilities[?defaultVersion==`true`]].addonVersion'
```

CoreDNS explicitly `depends_on` the node group, because CoreDNS runs as Pods — installing it into a cluster with no nodes leaves it stuck Pending.

## Access entries

```text
AWS IAM identity
       ↓
EKS Access Entry
       ↓
Kubernetes permissions
```

Two principals get access:

1. The **cluster creator** (your Terraform identity) — admin, via `bootstrap_cluster_creator_admin_permissions`.
2. The **GitHub deploy role** — `AmazonEKSEditPolicy` scoped to the `notes-app` **namespace only**:

```bash
grep -A12 "aws_eks_access_policy_association" ../infra/modules/eks/main.tf
```

Note what this is not: cluster-admin for convenience. CI can deploy the application and cannot touch platform controllers, other namespaces, or cluster-scoped resources.

## Pod Identity

```text
Kubernetes ServiceAccount
       ↓
EKS Pod Identity association
       ↓
IAM role
       ↓
temporary AWS credentials, rotated automatically
```

```bash
grep -B4 -A6 "aws_eks_pod_identity_association" ../infra/environments/staging/main.tf
```

Two associations, one role each:

* ServiceAccount `notes-app` in namespace `notes-app` → a role permitted `secretsmanager:GetSecretValue` on **exactly one secret ARN**.
* ServiceAccount `aws-load-balancer-controller` in `kube-system` → the official AWS-published controller policy.

The Pod never holds a static key, never sees an access key ID, and cannot use the node's role (hop limit 1). If the application were compromised, the blast radius is "can read one database password" — which it needs anyway.

### Pod Identity vs IRSA

IRSA (IAM Roles for Service Accounts) is the older mechanism, using an OIDC provider per cluster and a role annotation on the ServiceAccount. Pod Identity is newer, simpler (no per-cluster OIDC provider, no annotations) and is used here because both the AWS Load Balancer Controller and the AWS Secrets Manager CSI provider support it. Where a controller does not yet support Pod Identity, check its official documentation and use IRSA for that component specifically rather than guessing.

## Questions for the learner

1. What specifically prevents a compromised Pod from using the node's IAM role?
2. Why does CoreDNS need `depends_on` the node group when vpc-cni does not?
3. The GitHub role has `AmazonEKSEditPolicy` on one namespace. Could it delete the AWS Load Balancer Controller? Why not?

## Recap

Nodes are minimal, keyless and metadata-hardened; add-on versions are discovered rather than guessed; and both AWS and Kubernetes permissions are scoped to exactly what each identity needs. Next: the controllers that make Ingress and secrets work.
