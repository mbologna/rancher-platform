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
  description = "CIDR blocks allowed SSH access. Restrict to your IP in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
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

variable "ansible_user" {
  description = "SSH user for Ansible to connect as"
  type        = string
  default     = "ec2-user" # SLES default on AWS
}
