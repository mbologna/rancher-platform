variable "name" {
  description = "Prefix applied to all resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC in which to create the security group"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs allowed to SSH (22)"
  type        = list(string)
}

variable "allowed_admin_cidrs" {
  description = "CIDRs allowed to reach the Kubernetes API (6443) for kubectl"
  type        = list(string)
}

variable "allowed_cluster_cidrs" {
  description = <<-EOT
    CIDRs for downstream CAPI cluster nodes. They need to reach:
      - 6443        Kubernetes API (CAPI reconciliation)
      - 9345        RKE2 supervisor API
      - 30000-32767 Fleet + CAPI webhook NodePorts
      - 8472/udp    VXLAN overlay
    80/443 (Rancher UI, API, cluster-agent registration) are open to all.
  EOT
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
