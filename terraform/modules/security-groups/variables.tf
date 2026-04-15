variable "name" {
  description = "Prefix applied to all resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC in which to create the security group"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs allowed SSH (port 22). Should be your operator IP only."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_admin_cidrs" {
  description = "CIDRs allowed Rancher web UI (ports 80/443). Should be your IP only."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_cluster_cidrs" {
  description = <<-EOT
    CIDRs for downstream CAPI cluster nodes. These need to reach:
      - 443   (Rancher registration / cluster-agent callbacks)
      - 6443  (Kubernetes API — kubeconfig access and CAPI reconciliation)
      - 9345  (RKE2 supervisor API)
      - 30000-32767 (Fleet + CAPI webhook NodePorts)
    Typically the VPC CIDR of each downstream cluster's AWS region.
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
