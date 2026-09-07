# In-cluster platform layer.
#
# Deliberately separate from infra/environments/staging (which owns AWS
# resources) - see cloud-learning/08-helm-and-kubernetes-platform-controllers.md.
# This root owns cluster-wide capabilities that must exist before any
# application can deploy:
#
#   - the notes-app namespace (with Pod Security Admission labels)
#   - AWS Load Balancer Controller (turns Ingress objects into real ALBs)
#   - Secrets Store CSI driver + AWS provider (mounts Secrets Manager values)
#
# It does NOT own the Notes application itself. That is deployed by Helm from
# GitHub Actions, so Terraform and CI never fight over the same release.

data "terraform_remote_state" "infra" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = "environments/staging/terraform.tfstate"
    region = var.region
  }
}

locals {
  cluster_name = data.terraform_remote_state.infra.outputs.cluster_name
  vpc_id       = data.terraform_remote_state.infra.outputs.vpc_id
}

# --- Application namespace -------------------------------------------------

resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = var.application_namespace

    # Pod Security Admission, enforcing the `restricted` standard: the
    # strictest built-in Kubernetes profile. Any Pod that wants to run as
    # root, escalate privileges, or keep Linux capabilities is rejected by
    # the API server outright - not merely warned about.
    # See cloud-learning/14-kubernetes-workload-security.md.
    labels = {
      "pod-security.kubernetes.io/enforce"         = "restricted"
      "pod-security.kubernetes.io/enforce-version" = "latest"
      "pod-security.kubernetes.io/audit"           = "restricted"
      "pod-security.kubernetes.io/warn"            = "restricted"
      "app.kubernetes.io/managed-by"               = "terraform"
    }
  }
}

# --- AWS Load Balancer Controller ------------------------------------------
#
#   Ingress  ->  AWS Load Balancer Controller  ->  real AWS ALB
#
# The ALB is deliberately NOT created in Terraform. Kubernetes owns its own
# load balancer lifecycle, which is why deleting the Ingress also deletes the
# ALB (and why the teardown order in Lesson 17 matters).

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.lbc_chart_version # pinned, never "latest"
  namespace  = "kube-system"

  # The ServiceAccount name must match the EKS Pod Identity association
  # created in infra/environments/staging. No IRSA annotation is needed:
  # Pod Identity injects credentials without any annotation at all.
  values = [yamlencode({
    clusterName = local.cluster_name

    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
    }

    # One replica: this sandbox has a single worker node, and the chart's
    # default of 2 would leave a Pod permanently Pending. Production with
    # multiple nodes should keep 2 for controller availability.
    replicaCount = 1

    # Set explicitly because the controller cannot fall back to the EC2
    # metadata service: the node's IMDS hop limit is 1, which deliberately
    # blocks Pods from reading node credentials/metadata.
    region = var.region
    vpcId  = local.vpc_id
  })]

  wait    = true
  timeout = 600
}

# --- Secrets Store CSI driver + AWS provider -------------------------------
#
#   Secrets Manager  ->  AWS provider  ->  CSI driver  ->  file inside the Pod
#
# This is what lets the database password reach the application without ever
# existing as a Kubernetes Secret in Git, a Helm value, or an env var.
#
# ONE release, not two. The AWS provider chart declares the upstream
# secrets-store-csi-driver as a sub-chart dependency, so installing both
# separately makes two Helm releases fight over the same ServiceAccount:
#
#   invalid ownership metadata; annotation validation error:
#   key "meta.helm.sh/release-name" must equal "secrets-provider-aws"
#
# It also matters for correctness, not just tidiness: the sub-chart's default
# values request service-account tokens for the "pods.eks.amazonaws.com"
# audience, which is exactly what EKS Pod Identity needs. Installing the
# driver standalone would omit that and silently break secret retrieval.

resource "helm_release" "secrets_provider_aws" {
  name       = "secrets-provider-aws"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  version    = var.aws_provider_chart_version # pinned, never "latest"
  namespace  = "kube-system"

  values = [yamlencode({
    # Set explicitly rather than discovered: the node's IMDS hop limit is 1
    # (see the EKS module), so Pods cannot read region metadata themselves.
    awsRegion = var.region

    # Values for the bundled upstream CSI driver sub-chart.
    "secrets-store-csi-driver" = {
      install = true

      syncSecret = {
        # Not syncing to Kubernetes Secret objects: the password only ever
        # exists as a mounted file in the Pod that needs it, never as a
        # cluster-wide Secret any namespace reader could dump.
        enabled = false
      }

      enableSecretRotation = true
      rotationPollInterval = "2m"
    }
  })]

  wait    = true
  timeout = 600
}
