# Lesson 08 — Helm and Kubernetes Platform Controllers

**What you'll learn:** what Helm actually is, and the two controllers that make Ingress and Secrets Manager work in this cluster.

## Goal

Understand the controller pattern, and why an Ingress object does nothing without something watching for it.

## Helm is not just templating

Helm renders templates *and* tracks releases: a named, versioned, revision-history-bearing record of what was installed. That is what makes `helm rollback` possible, and what distinguishes it from `kubectl apply -f`.

```bash
helm list -n kube-system
helm status aws-load-balancer-controller -n kube-system
helm get values aws-load-balancer-controller -n kube-system
helm history aws-load-balancer-controller -n kube-system
```

## The controller pattern

```text
you create an object      ->    a controller notices    ->    it makes reality match
(Ingress)                       (watches the API)             (creates an AWS ALB)
```

This is Kubernetes' central idea. A controller is just a program in a reconcile loop: observe desired state, compare with actual state, act. Without a controller watching, an Ingress object is inert YAML in etcd.

## AWS Load Balancer Controller

```bash
grep -A25 'helm_release" "aws_load_balancer_controller' ../infra/platform/staging/main.tf
```

Installed via Helm at a **pinned** chart version (never `latest` — a floating chart version means an unreviewed controller upgrade arrives whenever someone re-runs apply).

Two settings deserve attention:

* **`replicaCount: 1`** — the chart defaults to 2 for controller availability. This cluster has one node, so the second replica would sit permanently `Pending`. Production with multiple nodes should keep 2.
* **`region` and `vpcId` set explicitly** — normally the controller discovers these from the EC2 metadata service. It cannot here, because Lesson 07 set the metadata hop limit to 1 specifically to stop Pods reaching IMDS. A security control in one layer created a configuration requirement in another; that interaction is worth internalising.

Its AWS permissions come from Pod Identity, using the **official AWS-published IAM policy**, fetched rather than hand-copied:

```bash
head -20 ../infra/environments/staging/policies/aws-load-balancer-controller.json
```

## Secrets Store CSI driver + AWS provider

Two charts working together:

* **secrets-store-csi-driver** — the generic Kubernetes CSI machinery for mounting secrets as files.
* **secrets-store-csi-driver-provider-aws** — the AWS-specific plugin that knows how to call Secrets Manager.

```bash
grep -A15 'helm_release" "secrets_store_csi_driver' ../infra/platform/staging/main.tf
```

Note `syncSecret.enabled = false`: the driver *can* mirror values into Kubernetes Secret objects, and deliberately does not. The password exists only as a file inside the one Pod that needs it — never as a cluster object anyone with namespace read access could dump.

## Verifying, not assuming

Never claim a controller works because Helm exited 0:

```bash
kubectl -n kube-system get deployment aws-load-balancer-controller
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl -n kube-system get daemonset -l app=secrets-store-csi-driver
```

A Deployment is only working when its Ready count matches its desired count.

## Ownership boundary

```text
Terraform (platform root)  ->  controllers, add-ons, namespace
Helm via GitHub Actions    ->  the Notes application release
```

Keeping these separate is what stops Terraform and CI fighting over the same objects — a genuinely common failure mode when application manifests get pulled into Terraform.

## Questions for the learner

1. Why would `replicaCount: 2` leave a Pod `Pending` on this cluster? What would `kubectl describe pod` say?
2. Trace the causal chain from "IMDS hop limit is 1" to "the Helm values must set `vpcId`".
3. What does `syncSecret.enabled = false` protect against, concretely?

## Recap

Controllers reconcile desired state into real infrastructure; Helm installs and versions them; and both are pinned, verified and owned by the platform layer rather than by application CI. Next: getting the application image into AWS.
