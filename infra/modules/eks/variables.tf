variable "name" {
  description = "Cluster name and prefix for related resources."
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version. Must be under standard support."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets for the control plane ENIs and the worker nodes."
  type        = list(string)
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public Kubernetes API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enabled_cluster_log_types" {
  description = "EKS control-plane log types to ship to CloudWatch Logs. Empty by default to avoid ingestion charges in a course sandbox."
  type        = list(string)
  default     = []
}

variable "node_instance_type" {
  description = "EC2 instance type for the managed node group."
  type        = string
  default     = "t3.medium"
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
  description = "Maximum worker nodes. Deliberately small to cap sandbox cost."
  type        = number
  default     = 2
}

variable "node_disk_size" {
  description = "Worker node root EBS volume size in GiB."
  type        = number
  default     = 20
}

variable "application_namespace" {
  description = "Kubernetes namespace the GitHub deploy role may write to."
  type        = string
  default     = "notes-app"
}

variable "enable_github_access" {
  description = "Create an EKS access entry for the GitHub deploy role. Must be statically known at plan time."
  type        = bool
  default     = true
}

variable "github_deploy_role_arn" {
  description = "IAM role ARN used by GitHub Actions, granted namespace-scoped Kubernetes access. Null disables the access entry."
  type        = string
  default     = null
}
