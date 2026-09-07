# EKS cluster, managed node group, add-ons and access entries.
#
# See cloud-learning/06-building-an-eks-cluster.md and
# cloud-learning/07-nodes-addons-access-and-pod-identity.md.
#
# Deliberate choices:
#   - a managed node group, NOT EKS Auto Mode and NOT Fargate, so the learner
#     can actually see nodes, node IAM roles and Pod scheduling
#   - API access entries, NOT the legacy aws-auth ConfigMap
#   - no SSH key and no port 22 anywhere: workloads are managed with kubectl

data "aws_partition" "current" {}

# --- Cluster IAM role ------------------------------------------------------

resource "aws_iam_role" "cluster" {
  name = "${var.name}-eks-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

# --- Cluster ---------------------------------------------------------------

resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids = var.subnet_ids

    # The API endpoint is public because GitHub-hosted runners must reach it
    # to run `helm upgrade`. This is NOT anonymous access: every request is
    # still authenticated by IAM and authorised by an access entry. Production
    # alternatives (private endpoint + self-hosted runners, VPN, or a
    # restricted CIDR allow-list) are discussed in the lesson.
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = var.public_access_cidrs
  }

  access_config {
    # API = access entries only. The legacy aws-auth ConfigMap is not used.
    authentication_mode = "API"

    # The identity running Terraform gets cluster-admin automatically, which
    # is what makes `kubectl` work immediately after creation.
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Control-plane logging is deliberately left off: it ships to CloudWatch
  # Logs and bills per GB ingested/stored, which is real money for a course
  # sandbox that will not read them. Production should enable at least the
  # `audit` and `authenticator` log types.
  enabled_cluster_log_types = var.enabled_cluster_log_types

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

# --- Node IAM role ---------------------------------------------------------
#
# Minimal by design: the three AWS-managed policies a node genuinely needs,
# and nothing else. Application AWS permissions come from Pod Identity
# instead, so Pods never inherit the node's identity.

resource "aws_iam_role" "node" {
  name = "${var.name}-eks-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "AmazonEKSWorkerNodePolicy",
    "AmazonEC2ContainerRegistryReadOnly",
    "AmazonEKS_CNI_Policy",
  ])

  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value}"
}

# --- Launch template: node hardening --------------------------------------

resource "aws_launch_template" "node" {
  name_prefix = "${var.name}-node-"

  # No key_name: there is deliberately no SSH access to worker nodes.

  metadata_options {
    http_endpoint = "enabled"
    # IMDSv2 only - blocks the classic SSRF-to-credential-theft path where a
    # compromised Pod reads the node's instance credentials over plain HTTP.
    http_tokens = "required"
    # Hop limit 1 means the metadata service is reachable from the node itself
    # but not from inside a container (whose traffic takes an extra hop), so
    # Pods cannot casually fall back to the node role's permissions.
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.node_disk_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring {
    # Basic (5-minute) CloudWatch metrics. Detailed monitoring costs extra and
    # Stage 5 will install Prometheus for real metrics anyway.
    enabled = false
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.name}-node"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- Managed node group ----------------------------------------------------

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-ng"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids

  instance_types = [var.node_instance_type]
  capacity_type  = "ON_DEMAND"

  scaling_config {
    min_size     = var.node_min_size
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  depends_on = [aws_iam_role_policy_attachment.node]

  lifecycle {
    # Nothing autoscales in this sandbox, but ignoring desired_size drift is
    # the conventional guard so a future autoscaler would not fight Terraform.
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# --- Managed add-ons -------------------------------------------------------
#
# Versions are resolved from what AWS currently reports as the default for
# this exact Kubernetes version, rather than hard-coded from a tutorial that
# may be years out of date.

data "aws_eks_addon_version" "this" {
  for_each = toset([
    "vpc-cni",
    "coredns",
    "kube-proxy",
    "eks-pod-identity-agent",
  ])

  addon_name         = each.value
  kubernetes_version = aws_eks_cluster.this.version
  most_recent        = false # the AWS-default version for this K8s version
}

# vpc-cni and kube-proxy have no Pod dependency, so they can install while the
# node group is still coming up.
resource "aws_eks_addon" "core" {
  for_each = toset(["vpc-cni", "kube-proxy", "eks-pod-identity-agent"])

  cluster_name  = aws_eks_cluster.this.name
  addon_name    = each.value
  addon_version = data.aws_eks_addon_version.this[each.value].version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

# CoreDNS runs as Pods, so it needs a node to schedule onto - without this
# dependency the add-on installs into an empty cluster and reports degraded.
resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "coredns"
  addon_version = data.aws_eks_addon_version.this["coredns"].version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.this]
}

# --- Access entries --------------------------------------------------------
#
#   AWS IAM identity  ->  EKS access entry  ->  Kubernetes permissions
#
# Note what is NOT here: no blanket cluster-admin for every AWS principal.

# The GitHub Actions deployment role gets Kubernetes access scoped to the
# application namespace only - it can deploy the Notes app and nothing else.
# count must be knowable at PLAN time. Deriving it from
# `github_deploy_role_arn` would make Terraform fail with "Invalid count
# argument", because that ARN does not exist until the IAM role is applied -
# hence a separate, statically-known boolean.
resource "aws_eks_access_entry" "github_deploy" {
  count = var.enable_github_access ? 1 : 0

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.github_deploy_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_deploy" {
  count = var.enable_github_access ? 1 : 0

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.github_deploy_role_arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = [var.application_namespace]
  }

  depends_on = [aws_eks_access_entry.github_deploy]
}
