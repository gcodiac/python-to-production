output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnets hosting the ALB and the EKS worker node."
  value       = aws_subnet.public[*].id
}

output "isolated_subnet_ids" {
  description = "Isolated subnets hosting RDS (no internet route)."
  value       = aws_subnet.isolated[*].id
}

output "availability_zones" {
  description = "Availability zones in use."
  value       = local.azs
}
