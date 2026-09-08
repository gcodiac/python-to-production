# Lesson 14 — Kubernetes Workload Security

**What you'll learn:** Pod Security Admission, security contexts, and how to verify the workload is actually locked down rather than merely declared to be.

## Goal

Explain every field in the Pod's security context, and check them on the running Pod.

## Pod Security Admission

```bash
kubectl get namespace notes-app -o jsonpath='{.metadata.labels}' | python3 -m json.tool
```

The namespace enforces the **`restricted`** profile — the strictest built-in Kubernetes standard. This is *admission control*: a Pod violating it is **rejected by the API server**, not merely flagged. Three levels exist:

```text
privileged   no restrictions
baseline     blocks known privilege escalations
restricted   heavily hardened; requires non-root, no capabilities, seccomp
```

`enforce` blocks, while `audit` and `warn` (also set) record and warn — useful for finding out what *would* break before enforcing.

## The security context

```bash
grep -A12 "podSecurityContext" ../k8s/charts/notes-app/values.yaml
grep -A8 "containerSecurityContext" ../k8s/charts/notes-app/values.yaml
```

| Setting | Why |
|---|---|
| `runAsNonRoot: true` | container root is not host root, but it is still unnecessary privilege |
| `runAsUser/Group: 1000` | matches the non-root user baked into the image in Stage 2 |
| `allowPrivilegeEscalation: false` | blocks `setuid` binaries from gaining more than the process started with |
| `readOnlyRootFilesystem: true` | an attacker cannot write a tool or a webshell to disk |
| `capabilities: drop: [ALL]` | this app needs no Linux capabilities at all |
| `seccompProfile: RuntimeDefault` | restricts which syscalls the container may make |

## Read-only root filesystem needs one honest accommodation

If the filesystem is read-only, anything the process legitimately writes needs an explicit volume:

```bash
grep -B3 -A4 "name: tmp" ../k8s/charts/notes-app/templates/deployment.yaml
```

`/tmp` is an `emptyDir` — ephemeral, per-Pod scratch that disappears with the Pod. This is the correct fix. The *wrong* fix would be setting `readOnlyRootFilesystem: false` because something failed to write.

Note the Stage 2 groundwork paying off: the image already sets `PYTHONDONTWRITEBYTECODE=1`, so Python does not try to write `.pyc` files into a read-only site-packages.

## Verifying, not trusting

Declared security means nothing until observed:

```bash
kubectl -n notes-app exec deploy/notes-app -- id
kubectl -n notes-app get pod -o jsonpath='{.items[0].spec.containers[0].securityContext}' | python3 -m json.tool
kubectl -n notes-app exec deploy/notes-app -- touch /test-write   # must fail
```

## Scanning the manifests

```bash
helm template notes-app ../k8s/charts/notes-app -f ../k8s/values/staging.yaml \
  --set image.repository=example/x --set image.digest=sha256:1111... > /tmp/rendered.yaml
trivy config /tmp/rendered.yaml
```

24 of 25 checks pass; the one failure is the `DB_PASSWORD_FILE` keyword false positive documented in Lesson 11. Every accepted finding is written down with reasoning:

```bash
cat ../.trivyignore.yaml
```

Things deliberately **not** present anywhere in this chart: privileged containers, `hostNetwork`, `hostPath` mounts, missing resource limits, added capabilities, or a mutable image tag.

## NetworkPolicy — taught, not claimed

Kubernetes `NetworkPolicy` restricts Pod-to-Pod traffic. Crucially, **it is only enforced if the CNI implements it**. The AWS VPC CNI requires network policy support to be explicitly enabled; without that, applying a NetworkPolicy creates an object that silently does nothing.

This course does not enable it, and therefore does not pretend the workload has network-level isolation it lacks. Claiming an unenforced NetworkPolicy is protection is worse than having none, because it produces false confidence.

Similarly, **Security Groups for Pods** allows AWS-level per-Pod network isolation. With a single workload whose only egress target is RDS — already restricted to the cluster security group — it would add complexity without meaningful benefit here.

## Questions for the learner

1. What does the API server do with a Pod that sets `privileged: true` in this namespace?
2. Why is adding an `emptyDir` for `/tmp` a better fix than disabling `readOnlyRootFilesystem`?
3. Why is applying a NetworkPolicy without CNI enforcement potentially worse than not applying one?

## Recap

The namespace enforces `restricted` admission, the Pod runs non-root with no capabilities and a read-only filesystem, and the one scanner finding is a documented false positive — all verified against the running Pod rather than asserted. Next: how CI deploys this without holding any AWS credential.
