# Lesson 13 — Ingress, Load Balancing and Health

**What you'll learn:** how an Ingress object becomes a real AWS ALB, why `target-type: ip` matters, and the liveness/readiness distinction that prevents restart loops.

## Goal

Explain the full path from a browser to the Pod, and why `/health` and `/ready` are different endpoints.

## Ingress to ALB

```text
Ingress object created
        ↓
AWS Load Balancer Controller notices
        ↓
creates a real ALB, listener, target group
        ↓
registers Pod IPs as targets
```

```bash
cat ../k8s/charts/notes-app/templates/ingress.yaml
kubectl -n notes-app get ingress
```

The ALB's lifecycle is owned by Kubernetes, not Terraform. Deleting the Ingress deletes the ALB — which is precisely why teardown order matters (Lesson 17): destroy the cluster first and the controller never gets to clean up, leaving an orphaned ALB that keeps billing.

## target-type: ip

```bash
grep -A6 "annotations" ../k8s/values/staging.yaml
```

```text
target-type: instance     ALB -> NodePort -> kube-proxy -> Pod   (extra hop)
target-type: ip           ALB -> Pod IP                          (direct)
```

With `ip`, the ALB health-checks the actual Pod rather than a node port, and there is one less hop. This works because the AWS VPC CNI gives every Pod a real VPC IP address — the Pod is directly routable within the VPC.

The Service stays a plain `ClusterIP`; no NodePort is needed.

## Liveness vs readiness — the important part

```text
/health   -> is the process alive?          (liveness)
/ready    -> can it serve requests now?     (readiness)
```

```bash
grep -A20 "def health_check" ../app/main.py
grep -A20 "def readiness_check" ../app/main.py
```

**`/health` deliberately does not touch the database.** If liveness depended on the database, a brief RDS blip would fail the liveness probe, Kubernetes would restart the Pod, the restart would not fix the database, and you would get a crash loop — turning a transient dependency problem into a self-inflicted outage.

**`/ready` does check the database**, because a Pod that cannot reach RDS should be removed from the ALB's rotation — without being restarted. When the database recovers, readiness passes and traffic returns automatically.

```bash
grep -A16 "livenessProbe" ../k8s/charts/notes-app/templates/deployment.yaml
```

## Do you need a startupProbe?

A `startupProbe` exists for applications with slow, variable startup — it suspends liveness checks until the app has booted, so a slow start is not mistaken for a hang.

This application starts in about a second. `initialDelaySeconds: 10` on the liveness probe covers it comfortably. Adding a startupProbe would be a Kubernetes feature used for its own sake, so it is deliberately omitted. A JVM application with a 90-second warm-up would be a genuine use case.

## Resource requests and limits

```bash
grep -A8 "resources" ../k8s/values/staging.yaml
```

```text
requests  = what the scheduler reserves    (used to decide placement)
limits    = the hard ceiling               (exceed memory -> OOMKilled)
```

Requests of 50m CPU / 128Mi memory reflect what this FastAPI process actually idles at; limits of 500m / 256Mi leave headroom without allowing one Pod to starve the node. Values chosen to be realistic rather than decorative.

## HTTP only, deliberately

No custom domain, no TLS. Production would be:

```text
Route 53 (DNS)
   ↓
ACM certificate
   ↓
HTTPS listener on the ALB (443, HTTP redirected)
```

Not provisioned here because it needs a real domain. Buying one, or faking a certificate, would add cost and confusion without adding understanding.

## Questions for the learner

1. Describe the failure mode if `/health` queried the database and RDS restarted for 30 seconds.
2. Why can the ALB target Pod IPs directly? What makes that possible in EKS specifically?
3. What happens to a Pod that exceeds its memory *limit*? What about its memory *request*?

## Recap

An Ingress plus a controller yields a real ALB targeting Pod IPs directly, and the liveness/readiness split ensures database trouble removes a Pod from rotation instead of restarting it pointlessly. Next: locking the workload down.
