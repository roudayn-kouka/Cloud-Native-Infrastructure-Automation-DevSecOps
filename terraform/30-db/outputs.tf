output "db_endpoint" {
  description = "Value for config.dbHost in gitops/environments/dev/values.yaml"
  value       = module.db.db_instance_address
}

output "db_secret_name" {
  value = aws_secretsmanager_secret.db.name
}
