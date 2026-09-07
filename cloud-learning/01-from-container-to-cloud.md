# Lesson 01 — From Container to Cloud

**What you'll learn:** what actually has to exist in AWS before a container image can serve traffic, and which of those things this course builds.

## Goal

Map the gap between "I have a trusted image" (end of Stage 3) and "users can reach the application".

## Why this matters

An image is inert. Turning it into a running service requires a surprising amount of surrounding infrastructure, and knowing what each piece is *for* is the difference between operating a system and cargo-culting a tutorial.

## What Stage 3 left us

A signed, attested, scanned image in GHCR, identified by an immutable digest. Nothing more.

## What has to exist for it to serve traffic

```text
Internet
   |
   v
Application Load Balancer      <- something with a public address
   |
   v
Kubernetes Ingress             <- routing rules
   |
   v
Service (ClusterIP)            <- stable virtual IP for a changing set of Pods
   |
   v
Deployment -> Pod              <- the running container
   |
   v
RDS PostgreSQL                 <- state that outlives any Pod
```

Underneath that, AWS needs:

```text
VPC + subnets + routing        <- a network to run in
EKS control plane              <- the Kubernetes API
Managed node group             <- EC2 capacity for Pods
ECR                            <- a registry AWS can pull from
IAM                            <- who may do what
Secrets Manager                <- the database password
GitHub OIDC provider           <- how CI authenticates without stored keys
```

## The registry question

The application image lives in GHCR. AWS *can* pull from GHCR, but this course copies it to **ECR** instead. Lesson 09 covers why (locality, IAM-native auth, lifecycle policies) and — importantly — how to do that **without rebuilding**, preserving the Stage 3 guarantee that the deployed artefact is the tested artefact.

## What this course does not build

* No production environment (one `staging` only).
* No NAT Gateway (Lesson 05 explains the cost/security trade-off).
* No managed observability (Prometheus/Grafana are Stage 5, self-hosted).
* No custom domain or TLS certificate (Lesson 13).

## Questions for the learner

1. Which of the components above stores state that must survive a Pod being deleted?
2. Why does a Service exist at all, given the Ingress could in principle route to a Pod IP?
3. The Stage 3 image is identified by a digest. Where in the list above does that digest need to be referenced for the deployment to be traceable?

## Recap

Running a container in the cloud is mostly a networking, identity and state problem — the container itself is the small part. Next: the runtime choice that shapes all of it.
