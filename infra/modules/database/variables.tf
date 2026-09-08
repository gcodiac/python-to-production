variable "name" {
  description = "Prefix for database resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC hosting the database."
  type        = string
}

variable "subnet_ids" {
  description = "Isolated subnets for the DB subnet group (two AZs minimum)."
  type        = list(string)
}

variable "source_security_group_id" {
  description = "Security group allowed to reach PostgreSQL (the EKS cluster SG)."
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "17.11"
}

variable "instance_class" {
  description = "RDS instance class. Smallest sensible option for a sandbox."
  type        = string
  default     = "db.t4g.micro"
}

variable "database_name" {
  description = "Initial database name."
  type        = string
  default     = "notes"
}

variable "master_username" {
  description = "Master username. Production should add a least-privilege application role instead of using this for the app."
  type        = string
  default     = "notes_admin"
}

variable "allocated_storage" {
  description = "Allocated storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = <<-EOT
    Storage autoscaling ceiling in GiB. 0 disables autoscaling entirely,
    which is what this sandbox wants: the Free Tier allowance is 20 GiB, and
    silently autoscaling past it would start billing without warning.
  EOT
  type        = number
  default     = 0
}

variable "backup_retention_days" {
  description = <<-EOT
    Automated backup retention in days. Deliberately non-zero so backups
    genuinely exist, but only 1 day: a Free Tier restricted account rejects
    anything longer with

      FreeTierRestrictionError: The specified backup retention period
      exceeds the maximum available to free tier customers.

    Production should retain far longer (7-35 days is typical).
  EOT
  type        = number
  default     = 1
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot on destroy. True for a disposable sandbox only."
  type        = bool
  default     = true
}
