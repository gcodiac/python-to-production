# Staging environment: the one real environment this course provisions.
#
# There is deliberately no production root. Production differences are taught
# in cloud-learning/17-costs-production-tradeoffs-and-teardown.md rather than
# built, because a second EKS cluster would roughly double the running cost
# for no additional learning.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  name = "${var.project}-${var.environment}"

  # Only these exact GitHub OIDC subjects may assume the deploy role. The tag
  # pattern mirrors the Stage 3 approach: a controlled, deliberate trigger
  # rather than "any push to any branch".
  #
  # The prefix is NOT simply "repo:owner/name". GitHub now issues subject
  # claims containing immutable numeric owner and repository IDs, so this
  # repository's real prefix is:
  #
  #   repo:gcodiac@42435299/python-to-production@1341833010
  #
  # Discover it for any repository with:
  #
  #   gh api repos/OWNER/NAME/actions/oidc/customization/sub
  #
  # Guessing the classic format produces exactly one symptom:
  # "Not authorized to perform sts:AssumeRoleWithWebIdentity" - see
  # cloud-learning/15-github-oidc-and-kubernetes-deployment.md.
  github_subjects = [
    "${var.github_oidc_subject_prefix}:ref:refs/tags/stage4-deploy-*",
    "${var.github_oidc_subject_prefix}:ref:refs/heads/${var.github_deploy_branch}",
  ]
}

module "network" {
  source = "../../modules/network"

  name     = local.name
  vpc_cidr = var.vpc_cidr
}

# --- Container registry ----------------------------------------------------

resource "aws_ecr_repository" "app" {
  name = local.name

  # PRIVATE by default - an ECR repository is only public if you explicitly
  # create a public one, which this deliberately is not.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    # ECR BASIC scanning is free, so there is no reason not to enable it -
    # it is a second opinion alongside the Trivy scan the release pipeline
    # already runs. What this does NOT enable is ENHANCED scanning, which
    # routes through Amazon Inspector and bills per image; that stays off,
    # and is a registry-level setting this configuration never turns on.
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  force_delete = true # sandbox convenience; production would be false
}

# Training builds accumulate quickly. This keeps storage costs near zero
# without anyone remembering to clean up.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the 10 most recent images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# --- EKS -------------------------------------------------------------------

module "eks" {
  source = "../../modules/eks"

  name               = local.name
  kubernetes_version = var.kubernetes_version
  subnet_ids         = module.network.public_subnet_ids

  node_instance_type = var.node_instance_type
  node_min_size      = var.node_min_size
  node_desired_size  = var.node_desired_size
  node_max_size      = var.node_max_size

  application_namespace  = var.application_namespace
  enable_github_access   = true
  github_deploy_role_arn = module.identity.github_deploy_role_arn
}

# --- Database --------------------------------------------------------------

module "database" {
  source = "../../modules/database"

  name       = local.name
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.isolated_subnet_ids

  # Only the cluster security group can reach PostgreSQL.
  source_security_group_id = module.eks.cluster_security_group_id

  engine_version = var.postgres_version
  instance_class = var.db_instance_class
  database_name  = var.database_name
}

# --- GitHub identity -------------------------------------------------------

module "identity" {
  source = "../../modules/identity"

  name             = local.name
  allowed_subjects = local.github_subjects

  ecr_repository_arn = aws_ecr_repository.app.arn
  eks_cluster_arn    = "arn:${data.aws_partition.current.partition}:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${local.name}"
  rds_instance_arn   = module.database.instance_arn

  create_oidc_provider = var.create_github_oidc_provider
}

# --- Application Pod Identity ---------------------------------------------
#
#   Kubernetes ServiceAccount  ->  Pod Identity association  ->  IAM role
#
# The Pod gets temporary AWS credentials for exactly one action: reading its
# own database secret. It never gets static keys and never inherits the node
# role - see cloud-learning/07-nodes-addons-access-and-pod-identity.md.

resource "aws_iam_role" "app_pod_identity" {
  name        = "${local.name}-app"
  description = "Assumed by the Notes application Pod via EKS Pod Identity."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

data "aws_iam_policy_document" "app_secret_read" {
  statement {
    sid    = "ReadOwnDatabaseSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    # Exactly one secret ARN - not "secretsmanager:*".
    resources = [module.database.master_secret_arn]
  }
}

resource "aws_iam_role_policy" "app_secret_read" {
  name   = "${local.name}-app-secret-read"
  role   = aws_iam_role.app_pod_identity.id
  policy = data.aws_iam_policy_document.app_secret_read.json
}

resource "aws_eks_pod_identity_association" "app" {
  cluster_name    = module.eks.cluster_name
  namespace       = var.application_namespace
  service_account = var.application_service_account
  role_arn        = aws_iam_role.app_pod_identity.arn
}

# --- AWS Load Balancer Controller Pod Identity -----------------------------
#
# The controller needs broad ELB permissions to create and manage ALBs on
# behalf of Ingress resources. Its policy is the official AWS-published one,
# fetched rather than hand-copied so it stays accurate.

resource "aws_iam_role" "lbc_pod_identity" {
  name        = "${local.name}-lbc"
  description = "AWS Load Balancer Controller, via EKS Pod Identity."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

resource "aws_iam_role_policy" "lbc" {
  name   = "${local.name}-lbc"
  role   = aws_iam_role.lbc_pod_identity.id
  policy = file("${path.module}/policies/aws-load-balancer-controller.json")
}

resource "aws_eks_pod_identity_association" "lbc" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lbc_pod_identity.arn
}
