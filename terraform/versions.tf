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

  # Uncomment to store state in S3 (recommended for teams)
  # backend "s3" {
  #   bucket = "my-terraform-state"
  #   key    = "rancher-platform/terraform.tfstate"
  #   region = "eu-west-1"
  # }
}
