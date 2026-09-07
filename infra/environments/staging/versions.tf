terraform {
  required_version = "~> 1.16"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state in the bucket created by infra/bootstrap.
  #
  # use_lockfile = true is Terraform's S3-native locking: the lock is an
  # object in the same bucket. Older tutorials create a DynamoDB table for
  # this; that approach is deprecated in the S3 backend and adds a resource
  # (and cost) for no benefit - see cloud-learning/04.
  backend "s3" {
    bucket       = "notes-app-tfstate-042724764568-eu-west-1"
    key          = "environments/staging/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  # No credentials here. The provider resolves them from the standard AWS
  # chain, so nothing secret is ever committed or stored in state.

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Course      = "python-to-production"
    }
  }
}
