# Lesson 16 — Deploying and Debugging the Real Application

**What you'll learn:** the commands that actually deploy, verify and troubleshoot the application on the real cluster.

## Goal

Deploy the Notes app, prove it uses PostgreSQL, prove Kubernetes self-heals, and know what to run when something is broken.

## First: is the cluster healthy?

```bash
aws eks update-kubeconfig --region eu-west-1 --name notes-app-staging
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
```

At least one node must be `Ready`, and the `kube-system` Pods (CoreDNS, aws-node, kube-proxy, pod-identity-agent) must be `Running`. **Do not deploy the application onto a broken cluster** — you will spend an hour debugging your chart for a cluster-level problem.

## Deploying

Triggered by a scoped tag (the same pattern Stage 3 used, since this branch is not the default branch):

```bash
git tag stage4-deploy-1
git push origin stage4-deploy-1
gh run watch <run-id> --exit-status
```

## Verifying it works

```bash
HOST=$(kubectl -n notes-app get ingress notes-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

curl -s "http://$HOST/health"
curl -s "http://$HOST/ready"
curl -s "http://$HOST/notes"
curl -s -X POST "http://$HOST/notes" -H 'Content-Type: application/json' \
  -d '{"title":"from the cloud","content":"stored in RDS"}'
```

`/ready` returning `{"status":"ready","database":"postgres"}` is the proof that the cloud deployment is genuinely on PostgreSQL rather than silently falling back to SQLite.

## Proving persistence: Pods are replaceable, RDS is not

```text
Pod  = replaceable
RDS  = persistent state
```

```bash
# 1. Create a note
curl -s -X POST "http://$HOST/notes" -H 'Content-Type: application/json' \
  -d '{"title":"survives pod deletion","content":"proof"}'

# 2. Delete the Pod entirely
kubectl -n notes-app delete pod -l app.kubernetes.io/name=notes-app

# 3. Watch Kubernetes create a replacement
kubectl -n notes-app get pods -w

# 4. The note is still there - it was never in the Pod
curl -s "http://$HOST/notes"
```

This single test demonstrates two things at once: **self-healing** (the ReplicaSet noticed a missing Pod and created another) and **externalised state** (the data lived in RDS, not in the container).

Note this required no intervention. Nobody restarted anything; a controller reconciled desired state.

## Debugging without the AWS Console

```bash
kubectl -n notes-app get deployment,pod,svc,ingress
kubectl -n notes-app describe pod <pod>          # events: scheduling, image pull, probe failures
kubectl -n notes-app logs deploy/notes-app        # stdout/stderr (Stage 2 made sure it goes there)
kubectl -n notes-app logs deploy/notes-app --previous   # logs from a crashed container
kubectl -n notes-app get events --sort-by=.lastTimestamp
kubectl top nodes && kubectl top pods -n notes-app       # needs metrics-server
```

`describe` is usually the fastest first step: the Events section at the bottom explains most failures (image pull errors, failed probes, insufficient CPU/memory, volume mount problems).

### Common failure signatures

| Symptom | Likely cause |
|---|---|
| `Pending` | no node capacity, or an unschedulable constraint |
| `ImagePullBackOff` | wrong digest, or node role lacks ECR permission |
| `CreateContainerConfigError` | secret/volume mount failing (check the CSI driver) |
| Ready 0/1, restarts climbing | liveness probe failing |
| Ready 0/1, no restarts | *readiness* failing — often the database |
| Ingress has no address | controller not running, or subnets missing `kubernetes.io/role/elb` |

That readiness-vs-liveness distinction in rows 4 and 5 is exactly why Lesson 13 separated the two endpoints.

## Helm operations

```bash
helm list -n notes-app
helm status notes-app -n notes-app
helm get values notes-app -n notes-app     # what was supplied (incl. the digest)
helm get manifest notes-app -n notes-app   # what was actually applied
helm history notes-app -n notes-app        # revisions
```

## Rollback: two mechanisms

```bash
# Kubernetes-level: revert the Deployment to its previous ReplicaSet
kubectl -n notes-app rollout history deployment/notes-app
kubectl -n notes-app rollout undo deployment/notes-app

# Helm-level: revert the whole release (values + all objects)
helm history notes-app -n notes-app
helm rollback notes-app <revision> -n notes-app
```

They are not the same. `kubectl rollout undo` changes the Deployment's Pod template but leaves Helm believing the current release is still deployed — the next `helm upgrade` will overwrite your rollback. `helm rollback` reverts the *release*, keeping Helm's view of the world consistent.

**Prefer `helm rollback` when Helm owns the deployment**, which it does here. Find the previously good image digest with `helm get values notes-app -n notes-app --revision <n>`.

## Drift

```bash
cd infra/environments/staging && terraform plan
```

"No changes" means reality matches the configuration. If someone changes something in the Console, this is what detects it.

## Questions for the learner

1. A Pod is `Ready 0/1` with zero restarts. Liveness or readiness? What do you check next?
2. Why does `kubectl rollout undo` risk being silently reverted later?
3. What proves the application is on PostgreSQL rather than SQLite?

## Recap

Deployment is verified by real HTTP responses, persistence is proved by deleting the Pod and finding the data intact, and debugging is done with `kubectl describe`, `logs` and `events` rather than the Console. Next: what it all costs and how to shut it down.
