variable "region" {
  description = "AWS region for the Terraform state bucket."
  type        = string
  default     = "eu-west-1"
}

variable "name_prefix" {
  description = "Prefix for globally-unique resource names."
  type        = string
  default     = "notes-app"
}
