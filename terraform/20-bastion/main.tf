locals {
  public_subnet_id = element(split(",", data.aws_ssm_parameter.public_subnet_ids.value), 0)
  name             = "${var.project_name}-${var.environment}"
}

data "aws_caller_identity" "current" {}

# What an operator needs on the bastion: read the DB secret, read the shared SSM parameters,
# and describe the cluster to build a kubeconfig. Cluster access itself is granted by an EKS access entry.
resource "aws_iam_policy" "bastion_ops" {
  name        = "${local.name}-bastion-ops"
  description = "Least-privilege operations policy for the bastion host"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadDbSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/db-*"
      },
      {
        Sid      = "ReadSharedParameters"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*"
      },
      {
        Sid      = "DescribeCluster"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster", "eks:ListClusters"]
        Resource = "*"
      }
    ]
  })
}

module "bastion" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.7"

  name = "${local.name}-bastion"

  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = local.public_subnet_id
  vpc_security_group_ids      = [data.aws_ssm_parameter.bastion_sg_id.value]
  associate_public_ip_address = true

  user_data                   = file("${path.module}/bastion.sh")
  user_data_replace_on_change = true

  # SSM Session Manager access (no inbound SSH needed)
  create_iam_instance_profile = true
  iam_role_description        = "Bastion host role (SSM Session Manager)"
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    BastionOps                   = aws_iam_policy.bastion_ops.arn
  }

  # IMDSv2 only
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device = [
    {
      encrypted   = true
      volume_type = "gp3"
      volume_size = 30
    }
  ]
}

# Lets 40-eks grant this role access to the cluster
resource "aws_ssm_parameter" "bastion_role_arn" {
  name  = "/${var.project_name}/${var.environment}/bastion_role_arn"
  type  = "String"
  value = module.bastion.iam_role_arn
}
