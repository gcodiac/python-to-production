output "state_bucket" {
  description = "S3 bucket holding Terraform remote state. Use this in each root's backend block."
  value       = aws_s3_bucket.state.id
}

output "region" {
  description = "Region the state bucket lives in."
  value       = var.region
}
