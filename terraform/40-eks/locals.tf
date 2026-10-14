locals {
  vpc_id             = data.aws_ssm_parameter.vpc_id.value
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
  cluster_sg_id      = data.aws_ssm_parameter.cluster_sg_id.value
  node_sg_id         = data.aws_ssm_parameter.node_sg_id.value
  cluster_name       = "${var.project_name}-${var.environment}"
}
