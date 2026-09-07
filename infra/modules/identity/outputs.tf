output "github_deploy_role_arn" {
  description = "IAM role ARN for GitHub Actions to assume via OIDC."
  value       = aws_iam_role.github_deploy.arn
}

output "oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN in use."
  value       = local.oidc_provider_arn
}
