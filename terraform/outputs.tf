output "rancher_public_ip" {
  description = "Public Elastic IP of the Rancher management node"
  value       = module.ec2.public_ip
}

output "rancher_public_dns" {
  description = "Public DNS hostname of the Elastic IP"
  value       = module.ec2.public_dns
}

output "rancher_url" {
  description = "Rancher UI URL (set DNS or /etc/hosts to this IP)"
  value       = "https://${module.ec2.public_ip}"
}

output "ssh_command" {
  description = "SSH command to connect to the management node"
  value       = "ssh ${var.ansible_user}@${module.ec2.public_ip}"
}

output "ansible_next_step" {
  description = "Command to run the Ansible playbook after terraform apply"
  value       = "cd ../ansible && ./manage.sh deploy"
}
