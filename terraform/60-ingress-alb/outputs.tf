output "frontend_target_group_arn" {
  description = "Value for targetGroupBinding.targetGroupARN in gitops/environments/dev/values.yaml"
  value       = aws_lb_target_group.frontend.arn
}

output "application_url" {
  value = "https://${local.hostname}"
}
