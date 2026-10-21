terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.60, < 6.70"
    }
  }

  # Partial configuration: bucket/region come from ../backend.hcl and the state key from
  # scripts/tf.sh (or `terraform init -backend-config=...`). See terraform/README.md.
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}
