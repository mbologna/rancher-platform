output "instance_id" {
  value = aws_instance.rancher.id
}

output "public_ip" {
  description = "Elastic IP of the Rancher management node"
  value       = aws_eip.rancher.public_ip
}

output "public_dns" {
  description = "Public DNS of the Elastic IP"
  value       = aws_eip.rancher.public_dns
}

output "private_ip" {
  value = aws_instance.rancher.private_ip
}
