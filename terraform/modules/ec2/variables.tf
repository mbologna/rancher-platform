variable "name" {
  description = "Prefix applied to all resource names"
  type        = string
}

variable "subnet_id" {
  description = "Subnet in which to launch the instance"
  type        = string
}

variable "security_group_id" {
  description = "Security group to attach to the instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the Rancher management node"
  type        = string
  default     = "t3.xlarge"
}

variable "root_volume_size_gb" {
  description = "Size of the root EBS volume in GiB"
  type        = number
  default     = 100
}

# Provide ONE of: public_key_path (creates key pair) or key_name (existing key pair)
variable "public_key_path" {
  description = "Path to a local SSH public key file. Leave empty to use key_name instead."
  type        = string
  default     = ""
}

variable "key_name" {
  description = "Name of an existing EC2 key pair. Used when public_key_path is empty."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
