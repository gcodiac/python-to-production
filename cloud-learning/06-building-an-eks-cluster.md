# Lesson 06 — Building an EKS Cluster

**What you'll learn:** how the cluster is defined, how the Kubernetes version was chosen, and the public-endpoint trade-off.

## Goal

Justify every non-obvious setting in `infra/modules/eks/main.tf`.

## Choosing a Kubernetes version

Never copy a version from a tutorial. Ask AWS what is currently supported:

```bash
aws eks describe-cluster-versions --region eu-west-1 \
  --query 'clusterVersions[].{v:clusterVersion,status:versionStatus,eos:endOfStandardSupportDate}' \
  --output table
```

When this course was built, that returned:

| Version | Status | End of standard support |
|---|---|---|
| 1.36 | STANDARD_SUPPORT (AWS default) | 2027-08-02 |
| 1.35 | STANDARD_SUPPORT | 2027-03-27 |
| 1.34 | STANDARD_SUPPORT | 2026-12-02 |
| 1.33 and below | **EXTENDED_SUPPORT** | — |

**1.36** was chosen: under standard support, the AWS default, the longest runway, and within one minor version of the kubectl in use (1.37), which matters because kubectl only guarantees compatibility within ±1 minor.

### Why extended support matters

After standard support ends, a version enters **extended support**, which costs significantly more per cluster-hour and signals an overdue upgrade. Running there by accident is a real and avoidable bill.

### Upgrades and version skew

EKS upgrades are one minor version at a time: control plane first, then node group, then add-ons. Nodes may run one minor behind the control plane, never ahead — which is why the control plane always goes first.

## The public endpoint trade-off

```bash
grep -A8 "vpc_config" ../infra/modules/eks/main.tf
```

`endpoint_public_access = true` because GitHub-hosted runners have no route into the VPC and must reach the Kubernetes API to run `helm upgrade`.

**A public endpoint is not an unauthenticated endpoint.** Every request is still authenticated by AWS IAM and authorised by an EKS access entry. The GitHub role's access is scoped to one namespace (Lesson 15).

That said, `public_access_cidrs = ["0.0.0.0/0"]` is the weakest point in this architecture, and it is stated as such in `.trivyignore.yaml` rather than glossed over. Production alternatives:

* private endpoint + **self-hosted runners** inside the VPC
* VPN or Direct Connect
* a restricted CIDR allow-list (viable when egress IPs are fixed)

## Access entries, not aws-auth

```bash
grep -A6 "access_config" ../infra/modules/eks/main.tf
```

`authentication_mode = "API"` means access is granted through **EKS Access Entries** — a real AWS API with IAM-style management. The legacy approach was hand-editing an `aws-auth` ConfigMap in the cluster, where a YAML typo could lock everyone out irrecoverably. Do not teach or use `aws-auth` for new clusters.

`bootstrap_cluster_creator_admin_permissions = true` grants the identity that created the cluster admin access, which is what makes `kubectl` work immediately afterwards.

## Control-plane logging is off

```bash
grep -B4 "enabled_cluster_log_types" ../infra/modules/eks/main.tf
```

EKS control-plane logs go to CloudWatch Logs and bill per GB ingested and stored. For a sandbox nobody will read, that is pure cost. **Production should enable at least `audit` and `authenticator`** — those are what let you answer "who did that?" after an incident.

## Questions for the learner

1. Run the `describe-cluster-versions` command today. Is 1.36 still under standard support? What would you choose now?
2. Why must the control plane be upgraded before the nodes, rather than after?
3. Someone argues the public API endpoint means "anyone on the internet can control our cluster". What is wrong with that statement, and what part of their concern is legitimate?

## Recap

The cluster pins a deliberately-chosen, standard-support Kubernetes version, uses modern access entries, and accepts one clearly-documented weakness (a public API endpoint) in exchange for CI being able to deploy at all. Next: the nodes it schedules onto.
