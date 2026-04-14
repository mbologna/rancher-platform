terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # Uncomment to store state in S3 (recommended for teams)
  # backend "s3" {
  #   bucket = "my-terraform-state"
  #   key    = "rancher-platform/terraform.tfstate"
  #   region = "eu-west-1"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  # Derive AZ from region if not explicitly set
  availability_zone = var.availability_zone != "" ? var.availability_zone : "${var.aws_region}a"
}

module "vpc" {
  source = "./modules/vpc"

  name              = var.project_name
  existing_vpc_id   = var.existing_vpc_id
  vpc_cidr          = var.vpc_cidr
  subnet_cidr       = var.subnet_cidr
  availability_zone = local.availability_zone
  tags              = local.common_tags
}

module "security_groups" {
  source = "./modules/security-groups"

  name                  = var.project_name
  vpc_id                = module.vpc.vpc_id
  allowed_ssh_cidrs     = var.allowed_ssh_cidrs
  allowed_admin_cidrs   = var.allowed_admin_cidrs
  allowed_cluster_cidrs = var.allowed_cluster_cidrs
  tags                  = local.common_tags
}

module "ec2" {
  source = "./modules/ec2"

  name                = var.project_name
  subnet_id           = module.vpc.public_subnet_id
  security_group_id   = module.security_groups.security_group_id
  instance_type       = var.instance_type
  root_volume_size_gb = var.root_volume_size_gb
  public_key_path     = var.public_key_path
  key_name            = var.key_name
  tags                = local.common_tags
}

# Write a ready-to-use Ansible inventory into terraform/generated/ — never overwrites the
# hand-edited ansible/inventory/hosts.yml so the Ansible role stays a standalone building block.
resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/generated/hosts.yml"
  file_permission = "0600"
  content = templatefile("${path.module}/templates/hosts.yml.tftpl", {
    public_ip    = module.ec2.public_ip
    ansible_user = var.ansible_user
    ssh_key_path = var.public_key_path != "" ? replace(var.public_key_path, ".pub", "") : "~/.ssh/id_rsa"
  })
}
