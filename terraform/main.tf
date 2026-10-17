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

  availability_zone = coalesce(var.availability_zone, "${var.aws_region}a")
  rancher_hostname  = coalesce(var.rancher_hostname, "rancher.${module.ec2.public_ip}.nip.io")
  public_key_path   = var.public_key_path != "" ? pathexpand(var.public_key_path) : ""
  private_key_path = coalesce(
    var.private_key_path,
    var.public_key_path != "" ? trimsuffix(var.public_key_path, ".pub") : "~/.ssh/id_rsa",
  )
}

module "vpc" {
  source = "./modules/vpc"

  name              = var.project_name
  existing_vpc_id   = var.existing_vpc_id
  vpc_cidr          = var.vpc_cidr
  subnet_cidr       = var.subnet_cidr
  availability_zone = local.availability_zone
}

module "security_groups" {
  source = "./modules/security-groups"

  name                  = var.project_name
  vpc_id                = module.vpc.vpc_id
  allowed_ssh_cidrs     = var.allowed_ssh_cidrs
  allowed_admin_cidrs   = var.allowed_admin_cidrs
  allowed_cluster_cidrs = var.allowed_cluster_cidrs
}

module "ec2" {
  source = "./modules/ec2"

  name                = var.project_name
  subnet_id           = module.vpc.public_subnet_id
  security_group_id   = module.security_groups.security_group_id
  instance_type       = var.instance_type
  root_volume_size_gb = var.root_volume_size_gb
  public_key_path     = local.public_key_path
  key_name            = var.key_name
  ami_name_filter     = var.ami_name_filter
  ami_owner           = var.ami_owner
}

# Write a ready-to-use Ansible inventory into terraform/generated/ — never overwrites the
# hand-edited ansible/inventory/hosts.yml so the Ansible role stays a standalone building block.
resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/generated/hosts.yml"
  file_permission = "0600"
  content = templatefile("${path.module}/templates/hosts.yml.tftpl", {
    public_ip        = module.ec2.public_ip
    ansible_user     = var.ansible_user
    private_key_path = local.private_key_path
    rancher_hostname = local.rancher_hostname
  })
}
