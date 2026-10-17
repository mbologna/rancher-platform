variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "availability_zone" {
  description = "Availability zone override. Defaults to <region>a when empty."
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Short name used as prefix for all resource names and tags"
  type        = string
  default     = "rancher-platform"
}

variable "environment" {
  description = "Environment label applied as a tag (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "existing_vpc_id" {
  description = "ID of an existing VPC to use. Leave empty to create a new VPC. Useful when at the AWS VPC limit."
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs allowed to SSH (22). Use your operator IP, e.g. [\"203.0.113.10/32\"]."
  type        = list(string)

  validation {
    condition     = length(var.allowed_ssh_cidrs) > 0 && !contains(var.allowed_ssh_cidrs, "0.0.0.0/0")
    error_message = "Set allowed_ssh_cidrs to your own IP range; 0.0.0.0/0 is not allowed."
  }
}

variable "allowed_admin_cidrs" {
  description = "CIDRs allowed to reach the Kubernetes API (6443) for kubectl. Use your operator IP. (80/443 are open to all.)"
  type        = list(string)

  validation {
    condition     = length(var.allowed_admin_cidrs) > 0 && !contains(var.allowed_admin_cidrs, "0.0.0.0/0")
    error_message = "Set allowed_admin_cidrs to your own IP range; 0.0.0.0/0 is not allowed."
  }
}

variable "allowed_cluster_cidrs" {
  description = "CIDRs of downstream CAPI cluster nodes, typically their VPC CIDRs. See the security-groups module for the ports they get."
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type for the Rancher management node"
  type        = string
  default     = "t3.xlarge" # 4 vCPU, 16 GB RAM — minimum comfortable for RKE2 + Rancher
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 100
}

# SSH key — provide ONE of the two options below
variable "public_key_path" {
  description = "Path to local SSH public key to upload as an EC2 key pair. Leave empty if using key_name."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair. Used when public_key_path is empty."
  type        = string
  default     = ""
}

variable "private_key_path" {
  description = "Private SSH key Ansible uses. Defaults to public_key_path without .pub (or ~/.ssh/id_rsa)."
  type        = string
  default     = ""
}

variable "ansible_user" {
  description = "SSH user for Ansible to connect as"
  type        = string
  default     = "ec2-user" # openSUSE/SLES default on AWS
}

variable "rancher_hostname" {
  description = "FQDN for Rancher. Defaults to rancher.<elastic-ip>.nip.io."
  type        = string
  default     = ""
}

variable "ami_name_filter" {
  description = "AMI name pattern for the management node (openSUSE Leap 16.0 by default)"
  type        = string
  default     = "openSUSE-Leap-16-0-v*-hvm-ssd-x86_64*"
}

variable "ami_owner" {
  description = "AWS account that publishes the AMI (SUSE)"
  type        = string
  default     = "679593333241"
}
