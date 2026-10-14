# Terraform — Infrastructure Setup Guide

Every numbered folder is an independent stack with its own state. Stacks share values (VPC id, subnet ids,
security-group ids, certificate ARN, …) through **SSM Parameter Store** under `/<project>/<environment>/…`,
so apply them in order and destroy them in reverse order.

| Stack | Creates |
|-------|---------|
| `00-bootstrap` | S3 bucket for remote state (versioned, KMS-encrypted, TLS-only). Local state, run once. |
| `00-vpc` | VPC, public / private / database subnets, NAT gateway, route tables, flow logs, DB subnet group |
| `10-sg` | Security groups: bastion, db, ingress (ALB), cluster, node + rules |
| `20-bastion` | Amazon Linux 2023 bastion (SSM Session Manager, kubectl, helm, eksctl, MySQL client) + scoped IAM policy |
| `30-db` | RDS MySQL 8.4 (encrypted, private) + generated passwords stored in **Secrets Manager** |
| `40-eks` | EKS cluster, managed node group (AL2023, Spot), add-ons, IRSA roles (Load Balancer Controller, EBS CSI), bastion access entry |
| `50-acm` | Wildcard ACM certificate validated through Route 53 |
| `60-ingress-alb` | Public ALB, HTTP→HTTPS redirect, frontend target group, listener rule, Route 53 alias |
| `70-ecr` | `expense-backend` / `expense-frontend` repositories (immutable tags, scan on push, lifecycle policy) |

## Prerequisites
* Terraform ≥ 1.10 (native S3 state locking), AWS CLI configured with an admin-capable identity
* A **public Route 53 hosted zone** that you own (for ACM validation and the application hostname)

## Step by step

```bash
# 1. Remote state bucket (once)
cd terraform/00-bootstrap
terraform init
terraform apply -var state_bucket_name=<globally-unique-name>
cd ..
cp backend.hcl.example backend.hcl        # set bucket = "<globally-unique-name>"

# 2. Inputs
export TF_VAR_zone_name=example.com                          # used by 50-acm and 60-ingress-alb
export TF_VAR_bastion_allowed_cidrs='["203.0.113.10/32"]'    # optional; empty = SSM only

# 3. All stacks, in order (one confirmation prompt per stack)
../scripts/tf.sh apply        # or: plan | destroy
```

`tf.sh` runs `terraform init -backend-config=../backend.hcl -backend-config=key=<project>/<env>/<stack>.tfstate`
in each folder. You can also run a single stack by hand with the same flags.

Useful variables (all have defaults): `project_name`, `environment`, `aws_region`, `single_nat_gateway`,
`cluster_version`, `node_capacity_type` (`SPOT` / `ON_DEMAND`), `node_*_size`, `multi_az`, `deletion_protection`,
`skip_final_snapshot`, `cluster_endpoint_public_access_cidrs`.

## After `apply`

| Output | Used for |
|--------|----------|
| `30-db` → `db_endpoint` | `config.dbHost` in `gitops/environments/dev/values.yaml` |
| `60-ingress-alb` → `frontend_target_group_arn` | `targetGroupBinding.targetGroupARN` in the same file |
| `20-bastion` → `bastion_instance_id` | `aws ssm start-session --target <id>` |
| `70-ecr` → `repository_urls` | ECR registry for `global.imageRegistry` |
| `40-eks` → `lb_controller_role_arn` | Read automatically (via SSM) by `scripts/bootstrap-cluster.sh` |

Then continue with the root README: database initialisation → cluster bootstrap → Jenkins → ArgoCD.

## Operating notes
* **Secrets**: DB passwords exist only in Terraform state (S3, encrypted) and Secrets Manager. Treat the state bucket as sensitive.
* **Versions**: the EKS version default follows the AWS support calendar — review `cluster_version` before each new environment; versions past standard support cost more.
* **Module versions** are pinned with `~>` ranges. Run `terraform init -upgrade` deliberately and review the plan.
* **Formatting**: run `terraform fmt -recursive` before committing (CI reports drift).
* **Tighten for production**: private-only API endpoint, `single_nat_gateway = false`, `multi_az = true`, `deletion_protection = true`, `skip_final_snapshot = false`, narrower node security-group rule (`node_from_vpc`), WAF on the ALB.
