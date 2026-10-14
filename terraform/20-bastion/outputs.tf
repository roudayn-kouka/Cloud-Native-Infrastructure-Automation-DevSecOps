output "bastion_instance_id" {
  description = "Connect with: aws ssm start-session --target <id>"
  value       = module.bastion.id
}

output "bastion_public_ip" {
  value = module.bastion.public_ip
}
