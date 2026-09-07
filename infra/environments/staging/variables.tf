variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  description = "Project name prefix."
  type        = string
  default     = "notes-app"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "staging"
}

variable "vpc_cidr" {
  description = "VPC CIDR."
  type        = string
  default     = "10.20.0.0/16"
}

variable "kubernetes_version" {
  description = <<-EOT
    EKS Kubernetes version. Must be under STANDARD support, never extended
    support (which costs more and signals an overdue upgrade). Verified with
    `aws eks describe-cluster-versions`.
  EOT
  type        = string
  default     = "1.36"
}

variable "node_instance_type" {
  description = <<-EOT
    Worker node instance type. x86_64, to match the amd64 application image.

    t3.small rather than the more comfortable t3.medium because this AWS
    account is Free Tier restricted and rejects non-free-tier-eligible types
    with "InvalidParameterCombination - The specified instance type is not
    eligible for Free Tier". Check what an account actually allows with:

      aws ec2 describe-instance-types --region eu-west-1 \
        --filters "Name=free-tier-eligible,Values=true"

    t3.small caps out around 11 pods, which is why CoreDNS is reduced to a
    single replica below - see cloud-learning/07.
  EOT
  type        = string
  default     = "t3.small"
}

variable "node_min_size" {
  description = "Minimum worker nodes."
  type        = number
  default     = 1
}

variable "node_desired_size" {
  description = "Desired worker nodes."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum worker nodes - a deliberate cost ceiling."
  type        = number
  default     = 2
}

variable "postgres_version" {
  description = "RDS PostgreSQL engine version."
  type        = string
  default     = "17.11"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "database_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  default     = "notes"
}

variable "application_namespace" {
  description = "Kubernetes namespace for the Notes application."
  type        = string
  default     = "notes-app"
}

variable "application_service_account" {
  description = "Kubernetes ServiceAccount used by the application Pod."
  type        = string
  default     = "notes-app"
}

variable "github_repository" {
  description = "GitHub repository trusted for OIDC, as owner/name."
  type        = string
  default     = "gcodiac/python-to-production"
}

variable "github_deploy_branch" {
  description = "Branch (in addition to stage4-deploy-* tags) allowed to assume the deploy role."
  type        = string
  default     = "devops/04-cloud-infrastructure"
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC provider. False if the account already has one."
  type        = bool
  default     = true
}
