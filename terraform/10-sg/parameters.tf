resource "aws_ssm_parameter" "sg_ids" {
  for_each = aws_security_group.this

  name  = "/${var.project_name}/${var.environment}/${each.key}_sg_id"
  type  = "String"
  value = each.value.id
}
