output "rancher_public_ip" {
  description = "Public Elastic IP of the Rancher management node"
  value       = module.ec2.public_ip
}

output "rancher_url" {
  description = "Rancher UI URL"
  value       = "https://${local.rancher_hostname}"
}

output "ssh_command" {
  description = "SSH command to connect to the management node"
  value       = "ssh -i ${local.private_key_path} ${var.ansible_user}@${module.ec2.public_ip}"
}

output "ansible_inventory" {
  description = "Generated Ansible inventory (picked up automatically by manage.sh)"
  value       = local_file.ansible_inventory.filename
}

output "ansible_next_step" {
  description = "Command to run after apply"
  value       = "cd ../ansible && ./manage.sh deploy"
}
