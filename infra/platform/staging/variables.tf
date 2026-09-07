variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-1"
}

variable "state_bucket" {
  description = "S3 bucket holding the staging infrastructure state."
  type        = string
  default     = "notes-app-tfstate-042724764568-eu-west-1"
}

variable "application_namespace" {
  description = "Namespace created for the Notes application."
  type        = string
  default     = "notes-app"
}

variable "lbc_chart_version" {
  description = "AWS Load Balancer Controller Helm chart version (pinned)."
  type        = string
  default     = "3.5.0"
}

variable "csi_driver_chart_version" {
  description = "Secrets Store CSI driver Helm chart version (pinned)."
  type        = string
  default     = "1.6.0"
}

variable "aws_provider_chart_version" {
  description = "AWS provider for Secrets Store CSI driver chart version (pinned)."
  type        = string
  default     = "3.1.3"
}
