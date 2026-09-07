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

# --- Secrets Store CSI driver ----------------------------------------------
#
#   Secrets Manager  ->  AWS provider  ->  CSI driver  ->  file inside the Pod
#
# This is what lets the database password reach the application without ever
# existing as a Kubernetes Secret in Git, a Helm value, or an env var.

resource "helm_release" "secrets_store_csi_driver" {
  name       = "secrets-store-csi-driver"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  version    = var.csi_driver_chart_version
  namespace  = "kube-system"

  values = [yamlencode({
    syncSecret = {
      # Not syncing to Kubernetes Secret objects: the password only ever
      # exists as a mounted file in the Pod that needs it, never as a
      # cluster-wide Secret any namespace reader could dump.
      enabled = false
    }
    enableSecretRotation = true
    rotationPollInterval = "2m"
  })]

  wait    = true
  timeout = 600
}

# The AWS-specific provider plugin for the CSI driver above.
resource "helm_release" "secrets_provider_aws" {
  name       = "secrets-provider-aws"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  version    = var.aws_provider_chart_version
  namespace  = "kube-system"

  wait    = true
  timeout = 600

  depends_on = [helm_release.secrets_store_csi_driver]
}
