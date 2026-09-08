# Lesson 05 — VPCs, Subnets, Routing and Security

**What you'll learn:** the network this course builds, and the single most consequential cost decision in it — no NAT Gateway.

## Goal

Explain why the worker node sits in a public subnet, why that is not as alarming as it sounds, and what production would do differently.

## The network

```text
Internet
   |
[ Internet Gateway ]
   |
public subnets (AZ-a, AZ-b)      10.20.0.0/20, 10.20.16.0/20
   ├── Application Load Balancer
   └── EKS worker node
   |
isolated subnets (AZ-a, AZ-b)    10.20.128.0/24, 10.20.129.0/24
   └── RDS PostgreSQL            (no route to the internet at all)
```

VPC CIDR: `10.20.0.0/16`. Two AZs, because EKS requires two for a cluster and RDS requires two for a DB subnet group — even though only one worker node runs.

## The NAT Gateway decision

A conventional production layout puts nodes in **private** subnets and routes their outbound traffic through a **NAT Gateway**. That is the safer default. It also costs roughly **$35/month plus per-GB data processing** — comfortably the largest avoidable line item in a sandbox this size.

So this course does not create one:

```bash
grep -rn "nat_gateway" ../infra/ || echo "no NAT Gateway anywhere"
```

Instead the node sits in a public subnet with `map_public_ip_on_launch = true`, giving it the outbound access it genuinely needs (pulling images, reaching the EKS control plane, calling AWS APIs).

## Why this is defensible here

"Public subnet" means *the subnet has a route to the internet gateway*. It does not mean "anything can connect in". Inbound protection comes from security groups:

* the node has **no SSH key and no port 22**
* the node exposes **no inbound application ports** to the internet
* application traffic arrives only via the **ALB**
* **RDS is in isolated subnets with no internet route at all**, is `publicly_accessible = false`, and accepts connections only from the cluster security group

Trivy flags this as `AWS-0164` ("Subnet associates public IP address"). That finding is **accepted, not suppressed silently** — the reasoning is written down in `.trivyignore.yaml`:

```bash
grep -A12 "id: AWS-0164" ../.trivyignore.yaml
```

## What production would do

```text
private node subnets
        +
NAT Gateway (or VPC endpoints for ECR/S3/STS/etc.)
```

VPC endpoints are the interesting middle ground: interface endpoints for ECR, STS, Secrets Manager and friends let private nodes work without a NAT Gateway, billed per endpoint-hour — often cheaper than NAT for a small number of services, and strictly more locked down.

## Subnet tagging matters

```bash
grep -A3 "kubernetes.io/role/elb" ../infra/modules/network/main.tf
```

The AWS Load Balancer Controller discovers where it may place a public ALB by looking for the `kubernetes.io/role/elb = 1` tag. Without it, Ingress creation fails with a confusing "no eligible subnets" error.

## Questions for the learner

1. What specifically stops someone connecting to the worker node from the internet, given it has a public IP?
2. RDS has `publicly_accessible = false` *and* sits in a subnet with no internet route. Why is having both worth it?
3. Estimate the monthly saving from omitting the NAT Gateway. Would you make the same call for a production system handling customer data?

## Recap

The network is deliberately flat and NAT-free to control cost, with security enforced by security groups and isolated subnets rather than by network topology alone — an explicit, documented trade-off rather than an oversight. Next: the cluster itself.
