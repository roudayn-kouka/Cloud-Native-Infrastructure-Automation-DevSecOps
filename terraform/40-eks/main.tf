resource "aws_key_pair" "eks" {
  count = var.ssh_public_key_path != "" ? 1 : 0

  key_name   = "${local.cluster_name}-nodes"
  public_key = file(var.ssh_public_key_path)
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.29"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_service_ipv4_cidr            = var.cluster_service_ipv4_cidr

  vpc_id                   = local.vpc_id
  subnet_ids               = local.private_subnet_ids
  control_plane_subnet_ids = local.private_subnet_ids

  # Security groups are managed in 10-sg
  create_cluster_security_group = false
  cluster_security_group_id     = local.cluster_sg_id
  create_node_security_group    = false
  node_security_group_id        = local.node_sg_id

  # The identity that runs Terraform becomes cluster admin
  enable_cluster_creator_admin_permissions = true

  # The bastion's instance role administers the cluster (kubectl/helm during bootstrap)
  access_entries = {
    bastion = {
      principal_arn = nonsensitive(data.aws_ssm_parameter.bastion_role_arn.value)

      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  # IAM Roles for Service Accounts (used by the Load Balancer Controller and the EBS CSI driver)
  enable_irsa = true

  cluster_enabled_log_types = ["api", "audit", "authenticator"]

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni = {
      # Enforce Kubernetes NetworkPolicies (see helm/expense/templates/networkpolicy.yaml)
      configuration_values = jsonencode({
        enableNetworkPolicy = "true"
      })
    }
  }

  eks_managed_node_groups = {
    main = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      key_name = var.ssh_public_key_path != "" ? aws_key_pair.eks[0].key_name : null

      # Least privilege: only SSM access is added to the node role. The load balancer controller
      # and the EBS CSI driver use IRSA roles instead of broad node permissions.
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
      }
    }
  }
}
