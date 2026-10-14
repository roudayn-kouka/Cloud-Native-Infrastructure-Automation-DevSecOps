locals {
  name   = "${var.project_name}-${var.environment}"
  vpc_id = data.aws_ssm_parameter.vpc_id.value

  security_groups = {
    bastion = "Bastion host"
    db      = "RDS MySQL"
    ingress = "Public ALB"
    cluster = "EKS control plane"
    node    = "EKS worker nodes"
  }
}

resource "aws_security_group" "this" {
  for_each = local.security_groups

  name        = "${local.name}-${each.key}"
  description = "SG for ${each.value}"
  vpc_id      = local.vpc_id

  tags = {
    Name = "${local.name}-${each.key}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Every group may reach anything (updates, ECR, AWS APIs); inbound rules are what matters.
resource "aws_vpc_security_group_egress_rule" "all" {
  for_each = aws_security_group.this

  security_group_id = each.value.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---- Bastion: SSH only from approved CIDRs (empty list = SSM only) -------------
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  for_each = toset(var.bastion_allowed_cidrs)

  security_group_id = aws_security_group.this["bastion"].id
  description       = "SSH from approved CIDR"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

# ---- Public ALB ---------------------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "ingress_https" {
  security_group_id = aws_security_group.this["ingress"].id
  description       = "HTTPS from the internet"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "ingress_http" {
  security_group_id = aws_security_group.this["ingress"].id
  description       = "HTTP from the internet (redirected to HTTPS by the ALB)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

# ---- EKS control plane ----------------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "cluster_from_bastion" {
  security_group_id            = aws_security_group.this["cluster"].id
  description                  = "kubectl from the bastion"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.this["bastion"].id
}

resource "aws_vpc_security_group_ingress_rule" "cluster_from_nodes" {
  security_group_id            = aws_security_group.this["cluster"].id
  description                  = "All traffic from worker nodes"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.this["node"].id
}

# ---- EKS worker nodes -----------------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "node_from_cluster" {
  security_group_id            = aws_security_group.this["node"].id
  description                  = "All traffic from the control plane"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.this["cluster"].id
}

resource "aws_vpc_security_group_ingress_rule" "node_from_vpc" {
  security_group_id = aws_security_group.this["node"].id
  description       = "Pod/node traffic inside the VPC (kept from the original design; tighten for production)"
  ip_protocol       = "-1"
  cidr_ipv4         = data.aws_ssm_parameter.vpc_cidr.value
}

resource "aws_vpc_security_group_ingress_rule" "node_from_alb_pods" {
  security_group_id            = aws_security_group.this["node"].id
  description                  = "ALB -> pods (target-type ip) on the frontend port"
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.this["ingress"].id
}

resource "aws_vpc_security_group_ingress_rule" "node_from_alb_nodeports" {
  security_group_id            = aws_security_group.this["node"].id
  description                  = "ALB -> NodePort range (instance targets)"
  ip_protocol                  = "tcp"
  from_port                    = 30000
  to_port                      = 32767
  referenced_security_group_id = aws_security_group.this["ingress"].id
}

# ---- Database -------------------------------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "db_from_bastion" {
  security_group_id            = aws_security_group.this["db"].id
  description                  = "MySQL from the bastion (administration)"
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.this["bastion"].id
}

resource "aws_vpc_security_group_ingress_rule" "db_from_nodes" {
  security_group_id            = aws_security_group.this["db"].id
  description                  = "MySQL from the EKS worker nodes (the backend pods)"
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.this["node"].id
}
