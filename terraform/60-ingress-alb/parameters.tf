resource "aws_ssm_parameter" "web_alb_listener_arn_https" {
  name  = "/${var.project_name}/${var.environment}/web_alb_listener_arn_https"
  type  = "String"
  value = aws_lb_listener.https.arn
}

resource "aws_ssm_parameter" "frontend_target_group_arn" {
  name  = "/${var.project_name}/${var.environment}/frontend_target_group_arn"
  type  = "String"
  value = aws_lb_target_group.frontend.arn
}
