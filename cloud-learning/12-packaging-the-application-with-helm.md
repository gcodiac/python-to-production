# Lesson 12 — Packaging the Application with Helm

**What you'll learn:** the structure of the Notes chart, what belongs in values versus templates, and what must never appear in either.

## Goal

Read `k8s/charts/notes-app/` and be able to explain every file's job.

## Structure

```text
k8s/
├── charts/notes-app/
│   ├── Chart.yaml                 # name, chart version, appVersion
│   ├── values.yaml                # defaults
│   └── templates/
│       ├── _helpers.tpl           # naming + the image-digest guard
│       ├── deployment.yaml        # the Pod spec
│       ├── service.yaml           # stable ClusterIP
│       ├── ingress.yaml           # ALB routing rules
│       ├── configmap.yaml         # non-secret configuration
│       ├── serviceaccount.yaml    # identity for Pod Identity
│       └── secretproviderclass.yaml
└── values/staging.yaml            # environment-specific, non-secret
```

Deliberately not a generic corporate chart framework — no library charts, no conditional sub-charts, nothing that obscures what is being deployed.

## Values versus templates

**Templates** describe *shape*. **Values** describe *this environment's* choices.

`k8s/values/staging.yaml` may contain replica count, resources, non-secret config and ingress annotations. It must **never** contain a database password, AWS credentials, or application secrets:

```bash
cat ../k8s/values/staging.yaml
```

Two values are supplied by CI rather than committed — `image.repository` and `image.digest` — so the file never pins a stale image.

## The digest guard

```bash
grep -A12 "notes-app.image" ../k8s/charts/notes-app/templates/_helpers.tpl
```

The helper calls `fail` if no digest is provided. Rendering is impossible with a tag alone. This makes "deploy by immutable digest" a property the chart enforces, rather than a convention people remember most of the time.

## ConfigMap and the checksum annotation

```bash
grep -B2 -A4 "checksum/config" ../k8s/charts/notes-app/templates/deployment.yaml
```

Changing a ConfigMap does **not** restart Pods by itself — running containers keep the values they started with. Hashing the rendered ConfigMap into a Pod annotation changes the Pod template whenever config changes, which triggers a rollout. Without this, config changes appear to do nothing.

## ServiceAccount

```bash
cat ../k8s/charts/notes-app/templates/serviceaccount.yaml
```

Note the absence of an IAM role annotation. That is the IRSA pattern; **Pod Identity** needs no annotation at all — the association lives entirely on the AWS side, so the cluster holds no AWS identifiers.

## Rolling update strategy

```bash
grep -A8 "strategy" ../k8s/charts/notes-app/templates/deployment.yaml
```

`maxUnavailable: 0`, `maxSurge: 1` — the new Pod must become Ready before the old one is removed, so even a single-replica deployment rolls without dropping traffic. It does require the node to have capacity for two Pods briefly.

## Deliberately absent

* **No PodDisruptionBudget.** With one replica, a PDB of `minAvailable: 1` blocks voluntary evictions entirely — including node drains during upgrades. Useful in production with several replicas; actively confusing here.
* **No HorizontalPodAutoscaler.** HPA needs metrics infrastructure, which is Stage 5. `replicas: 1` is honest for now.

Both are taught as concepts rather than added for completeness.

## Useful Helm operations

```bash
helm list -n notes-app
helm status notes-app -n notes-app
helm get values notes-app -n notes-app       # what was actually supplied
helm get manifest notes-app -n notes-app     # what was actually applied
helm history notes-app -n notes-app          # revisions, for rollback
```

## Questions for the learner

1. What happens if you change `LOG_LEVEL` in the ConfigMap and the checksum annotation does not exist?
2. Why does `maxUnavailable: 0` require spare node capacity?
3. Why is a PodDisruptionBudget a bad idea with exactly one replica?

## Recap

The chart is small, enforces deployment-by-digest, keeps secrets out of values entirely, and omits the Kubernetes objects that would be cargo-cult at this scale. Next: how traffic actually reaches it.
