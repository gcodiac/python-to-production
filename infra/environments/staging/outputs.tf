output "cluster_name" {
  description = "EKS cluster name - use with `aws eks update-kubeconfig`."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version."
  value       = module.eks.cluster_version
}

output "addon_versions" {
  description = "EKS managed add-on versions installed."
  value       = module.eks.addon_versions
}

output "ecr_repository_url" {
  description = "Private ECR repository URL."
  value       = aws_ecr_repository.app.repository_url
}

output "db_endpoint" {
  description = "RDS endpoint hostname (not publicly reachable)."
  value       = module.database.endpoint_address
}

output "db_name" {
  description = "PostgreSQL database name."
  value       = module.database.database_name
}

output "db_username" {
  description = "PostgreSQL master username (not a secret; the password lives in Secrets Manager)."
  value       = module.database.master_username
}

output "db_master_secret_arn" {
  description = "Secrets Manager ARN holding RDS-managed credentials."
  value       = module.database.master_secret_arn
}

output "github_deploy_role_arn" {
  description = "Role GitHub Actions assumes via OIDC."
  value       = module.identity.github_deploy_role_arn
}

output "app_pod_identity_role_arn" {
  description = "IAM role the application Pod assumes via Pod Identity."
  value       = aws_iam_role.app_pod_identity.arn
}

output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnets (ALB + nodes)."
  value       = module.network.public_subnet_ids
}
