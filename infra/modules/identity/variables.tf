variable "name" {
  description = "Prefix for identity resources."
  type        = string
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false if the account already has one."
  type        = bool
  default     = true
}

variable "existing_oidc_provider_arn" {
  description = "ARN of a pre-existing GitHub OIDC provider, used when create_oidc_provider is false."
  type        = string
  default     = null
}

variable "github_thumbprints" {
  description = "Certificate thumbprints for GitHub's OIDC endpoint."
  type        = list(string)
  default     = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

variable "allowed_subjects" {
  description = <<-EOT
    Exact GitHub OIDC subject patterns allowed to assume the deploy role.
    Must be tightly scoped - never "repo:*/*" and never a bare
    "repo:owner/name:*" that would trust every branch and pull request.
  EOT
  type        = list(string)
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository the deploy role may push to."
  type        = string
}

variable "eks_cluster_arn" {
  description = "ARN of the EKS cluster the deploy role may describe."
  type        = string
}
