# Terraform remote state bootstrap.
#
# The chicken-and-egg problem this solves: Terraform wants to keep its state
# in S3, but the S3 bucket itself has to be created by something. So this one
# small root starts with LOCAL state, creates the bucket, and then migrates
# its own state into that bucket - see
# cloud-learning/04-terraform-state-and-bootstrap.md.
#
# This is the only Terraform root in the project that is ever run with local
# state, and only for its very first apply.

terraform {
  required_version = "~> 1.16"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Enabled after the first apply created this bucket, then migrated with
  # `terraform init -migrate-state`. Note the bucket now stores the state that
  # describes the bucket itself - which is exactly why it is never
  # force-destroyable and why teardown treats it separately (lesson 17).
  backend "s3" {
    bucket       = "notes-app-tfstate-042724764568-eu-west-1"
    key          = "bootstrap/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  # No access_key/secret_key here, ever. The provider uses the normal AWS
  # credential chain (environment, shared config, instance/role credentials),
  # so no secret material lives in this repository or in state.

  default_tags {
    tags = {
      Project     = "notes-app"
      Environment = "shared"
      ManagedBy   = "terraform"
      Course      = "python-to-production"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  # Account ID in the name keeps the globally-unique S3 namespace collision-free.
  bucket_name = "${var.name_prefix}-tfstate-${data.aws_caller_identity.current.account_id}-${var.region}"
}

resource "aws_s3_bucket" "state" {
  bucket = local.bucket_name

  # This bucket holds Terraform state for the whole course. Losing it means
  # losing Terraform's record of what it created, so it is deliberately not
  # force-destroyable by accident.
  force_destroy = false
}

# Versioning is the real safety net: a corrupted or truncated state file can
# be rolled back to a previous object version.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# State can contain sensitive values, so it is encrypted at rest. SSE-S3
# (AES256) is sufficient here and costs nothing; production may prefer a
# customer-managed KMS key for key rotation and access auditing.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Old state versions are useful for recovery but not forever - expire them so
# the bucket does not grow without bound.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  depends_on = [aws_s3_bucket_versioning.state]

  rule {
    id     = "expire-noncurrent-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
