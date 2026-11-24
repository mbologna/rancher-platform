terraform {
  # Works with Terraform and OpenTofu. Keep this a floor, not the latest release.
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.67"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.9"
    }
  }

  # State is local; copy backend.tf.example to backend.tf to keep it in S3.
}
