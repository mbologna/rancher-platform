# Data source: latest openSUSE Leap 15.6 AMI published by SUSE (free, no subscription required)
data "aws_ami" "opensuse" {
  most_recent = true
  owners      = ["679593333241"] # SUSE's official AWS account

  filter {
    name   = "name"
    values = ["openSUSE-Leap-15.6-HVM-x86_64*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_key_pair" "rancher" {
  count      = var.public_key_path != "" ? 1 : 0
  key_name   = "${var.name}-key"
  public_key = file(var.public_key_path)
  tags       = var.tags
}

resource "aws_instance" "rancher" {
  ami                    = data.aws_ami.opensuse.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.public_key_path != "" ? aws_key_pair.rancher[0].key_name : var.key_name

  root_block_device {
    volume_size           = var.root_volume_size_gb
    volume_type           = "gp3"
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2
    http_put_response_hop_limit = 2
  }

  tags = merge(var.tags, { Name = "${var.name}-rancher" })

  lifecycle {
    ignore_changes = [ami] # Don't replace instance on AMI updates
  }
}

resource "aws_eip" "rancher" {
  instance = aws_instance.rancher.id
  domain   = "vpc"
  tags     = merge(var.tags, { Name = "${var.name}-rancher-eip" })
}
