# RDS PostgreSQL for staging.
#
# See cloud-learning/10-rds-postgresql-and-persistent-data.md and
# cloud-learning/11-secrets-manager-and-kubernetes-secrets.md.
#
# The credential model matters as much as the database:
#
#   RDS generates the master password
#         v
#   AWS Secrets Manager stores it (managed, rotatable)
#         v
#   EKS Pod Identity lets the Pod read that one secret
#         v
#   Secrets Store CSI mounts it as a file
#         v
#   application reads DB_PASSWORD_FILE
#
# Notably, the password never passes through Terraform, so it never lands in
# Terraform state - which is why `manage_master_user_password` is used instead
# of the common `random_password` pattern.

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db"
  subnet_ids = var.subnet_ids

  description = "Isolated subnets for ${var.name} PostgreSQL"
}

# The database's own security group: no ingress rule is defined inline, only
# the single explicit rule below. Anything not listed cannot reach port 5432.
resource "aws_security_group" "db" {
  name        = "${var.name}-db"
  description = "PostgreSQL access for ${var.name}"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-db"
  }
}

# The ONLY way into the database: from the EKS cluster security group, on the
# PostgreSQL port. No 0.0.0.0/0, no "temporarily open it to debug".
resource "aws_vpc_security_group_ingress_rule" "from_cluster" {
  security_group_id = aws_security_group.db.id
  description       = "PostgreSQL from the EKS cluster security group"

  referenced_security_group_id = var.source_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_db_instance" "this" {
  identifier = "${var.name}-postgres"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.database_name
  username = var.master_username

  # RDS creates and rotates the master password directly into Secrets Manager.
  # Terraform never sees the value, so it cannot leak into state or a plan.
  manage_master_user_password = true

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]

  # The database has no public endpoint at all. Combined with the isolated
  # subnets (no internet route), this is defence in depth rather than a single
  # flag standing between the database and the internet.
  publicly_accessible = false

  # Single-AZ: a staging sandbox does not need standby failover, and Multi-AZ
  # roughly doubles the instance cost. Production would enable it.
  multi_az = false

  backup_retention_period = var.backup_retention_days
  backup_window           = "02:00-03:00"
  maintenance_window      = "Mon:03:30-Mon:04:30"

  auto_minor_version_upgrade = true

  # Off deliberately: both bill extra and Stage 5 installs Prometheus for real
  # metrics instead.
  performance_insights_enabled = false
  monitoring_interval          = 0

  # Disabled so this training environment can actually be torn down.
  # Production would set this to true and mean it.
  deletion_protection = false

  skip_final_snapshot = var.skip_final_snapshot

  apply_immediately = true

  tags = {
    Name = "${var.name}-postgres"
  }
}
