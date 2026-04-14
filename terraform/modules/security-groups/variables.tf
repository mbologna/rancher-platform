variable "name" {
  description = "Prefix applied to all resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC in which to create the security group"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to reach port 22. Restrict to your IP in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
