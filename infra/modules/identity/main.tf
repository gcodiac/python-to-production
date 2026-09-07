# GitHub Actions -> AWS trust, without any stored access key.
#
#   GitHub Actions job
#         |  requests an OIDC token describing exactly which repo/ref it is
#         v
#   token.actions.githubusercontent.com
#         |
#         v
#   AWS IAM OIDC provider  ->  sts:AssumeRoleWithWebIdentity  ->  15-minute credentials
#
# See cloud-learning/15-github-oidc-and-kubernetes-deployment.md.

# The account may already have this provider (it is a per-account singleton).
# Setting create_oidc_provider = false lets a caller reference the existing one
# instead of failing on a duplicate.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub rotates these; AWS now verifies GitHub's OIDC certificate against
  # its own trust store, so this list is legacy but still required by the API.
  thumbprint_list = var.github_thumbprints
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.existing_oidc_provider_arn

  # Exactly which workflow identities may assume the deploy role. Anything not
  # matching these is refused by STS before the workflow gets any credential.
  allowed_subjects = var.allowed_subjects
}

# --- GitHub deployment role ------------------------------------------------

resource "aws_iam_role" "github_deploy" {
  name        = "${var.name}-github-deploy"
  description = "Assumed by GitHub Actions via OIDC to deploy the Notes application."

  # Sessions are short-lived by design; deployment takes minutes, not hours.
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        # Audience check: the token really was minted for AWS STS.
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        # Subject check: the token came from THIS repository, and only from
        # the specific refs listed. Never `repo:*/*`, and never a bare
        # `repo:owner/repo:*` that would trust every branch and every PR.
        StringLike = {
          "token.actions.githubusercontent.com:sub" = local.allowed_subjects
        }
      }
    }]
  })
}

# Least privilege: what a deployment genuinely needs, and nothing more.
# Notably absent: creating VPCs, IAM roles, EKS clusters, or deleting RDS.
# Infrastructure provisioning stays a local Terraform-admin activity.
data "aws_iam_policy_document" "github_deploy" {
  # Registry login token is account-wide by API design and cannot be
  # resource-scoped.
  statement {
    sid       = "EcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Push/pull, scoped to this one repository - not every repository in the
  # account.
  statement {
    sid    = "EcrPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [var.ecr_repository_arn]
  }

  # Enough to run `aws eks update-kubeconfig`. Kubernetes-level authorisation
  # is granted separately by a namespace-scoped EKS access entry, so this role
  # cannot do anything cluster-wide.
  statement {
    sid       = "EksDescribe"
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = [var.eks_cluster_arn]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "${var.name}-github-deploy"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}
