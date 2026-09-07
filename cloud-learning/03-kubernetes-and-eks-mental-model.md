# Lesson 03 — Kubernetes and EKS Mental Model

**What you'll learn:** the handful of Kubernetes objects this course actually uses, and what EKS manages versus what you manage.

## Goal

Be able to explain, without looking anything up, what a Deployment/ReplicaSet/Pod relationship is and where the ALB fits.

## The cluster

```text
EKS cluster
    |
    +-- control plane        <- AWS runs this. You never see the servers.
    |     (API server, scheduler, controller manager, etcd)
    |
    +-- nodes                <- YOU run these (EC2 instances in your VPC)
          |
          +-- Pods           <- your containers
```

EKS's $0.10/hour buys the control plane: a managed, highly-available Kubernetes API you do not patch, back up or scale. Everything below the API — nodes, add-ons, workloads — remains your responsibility. This is exactly why EKS Auto Mode and Fargate exist, and exactly why this course avoids them: the goal is to *see* the parts.

## Workload objects

```text
Deployment          <- desired state: "3 replicas of this image"
   |
   v
ReplicaSet          <- created by the Deployment; owns a specific Pod template
   |
   v
Pod                 <- one or more containers, scheduled onto a node
```

The indirection matters during a rollout: a Deployment creates a *new* ReplicaSet for the new Pod template and scales it up while scaling the old one down. That is what `kubectl rollout undo` reverses — it points back at the previous ReplicaSet.

## Networking objects

```text
Ingress             <- L7 routing rules ("/ goes to this Service")
   |
   v
Service (ClusterIP) <- stable virtual IP + DNS name for a changing Pod set
   |
   v
Pod                 <- ephemeral, gets a new IP every time it is recreated
```

A Pod's IP changes constantly. A Service gives a stable address; an Ingress gives HTTP routing. In EKS, an Ingress object does nothing by itself — a **controller** must be watching for it. That is what the AWS Load Balancer Controller does (Lesson 08): it sees the Ingress and creates a real ALB.

## Namespaces

Logical partitions. This course uses:

* `kube-system` — platform controllers and add-ons
* `notes-app` — the application

Namespaces are also a security boundary: the GitHub deploy role can write to `notes-app` and nowhere else (Lesson 15), and Pod Security Admission is enforced per namespace (Lesson 14).

## Declarative, not imperative

You do not tell Kubernetes "start a container". You declare desired state, and controllers continuously reconcile reality toward it. This is why deleting a Pod does not remove the application — the ReplicaSet notices and creates another. Lesson 16 demonstrates this for real.

## Questions for the learner

1. If you delete a Pod that belongs to a Deployment, what recreates it, and why?
2. Why can't the Ingress route directly to Pod IPs without a Service?
3. What exactly does AWS manage for the $0.10/hour EKS control-plane charge?

## Recap

Kubernetes is a set of controllers reconciling declared state. EKS manages the API; you manage the nodes and workloads. Next: making infrastructure reproducible with Terraform state.
