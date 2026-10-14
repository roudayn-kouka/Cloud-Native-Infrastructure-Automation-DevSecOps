output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "lb_controller_role_arn" {
  description = "Export as LB_CONTROLLER_ROLE_ARN before running scripts/bootstrap-cluster.sh"
  value       = module.lb_controller_irsa.iam_role_arn
}
