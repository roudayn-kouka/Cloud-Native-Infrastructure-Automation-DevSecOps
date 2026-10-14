resource "aws_ssm_parameter" "lb_controller_role_arn" {
  name  = "/${var.project_name}/${var.environment}/lb_controller_role_arn"
  type  = "String"
  value = module.lb_controller_irsa.iam_role_arn
}
