resource "aws_security_group" "rancher" {
  name        = "${var.name}-rancher-sg"
  description = "Security group for Rancher management node"
  vpc_id      = var.vpc_id

  # SSH — your operator IP only
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # HTTP — redirect to HTTPS; your IP + downstream clusters (Rancher agent callbacks)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = concat(var.allowed_admin_cidrs, var.allowed_cluster_cidrs)
  }

  # HTTPS — Rancher UI (your IP) + cluster-agent registration (downstream clusters)
  ingress {
    description = "HTTPS (Rancher UI/API + cluster registration)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = concat(var.allowed_admin_cidrs, var.allowed_cluster_cidrs)
  }

  # Kubernetes API — kubeconfig access (your IP) + CAPI reconciliation (downstream clusters)
  ingress {
    description = "Kubernetes API server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = concat(var.allowed_admin_cidrs, var.allowed_cluster_cidrs)
  }

  # RKE2 supervisor API — downstream clusters only
  ingress {
    description = "RKE2 supervisor"
    from_port   = 9345
    to_port     = 9345
    protocol    = "tcp"
    cidr_blocks = var.allowed_cluster_cidrs
  }

  # NodePort range — Fleet + CAPI webhooks called by downstream clusters
  ingress {
    description = "NodePort services (Fleet/CAPI webhooks)"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = var.allowed_cluster_cidrs
  }

  # VXLAN — overlay traffic from downstream cluster nodes
  ingress {
    description = "VXLAN overlay"
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = var.allowed_cluster_cidrs
  }

  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-rancher-sg" })
}
