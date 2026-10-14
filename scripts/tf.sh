#!/bin/bash
# Runs a Terraform command across all stacks in dependency order.
#   ./tf.sh apply      # 00-vpc ... 70-ecr  (asks for confirmation per stack)
#   ./tf.sh destroy    # reverse order
#   ./tf.sh plan
# Requires terraform/backend.hcl (copy terraform/backend.hcl.example) and terraform/common.auto.tfvars
# is optional; each stack also reads terraform.tfvars from its own directory.
set -euo pipefail
cd "$(dirname "$0")/../terraform"
source ../scripts/lib.sh
need terraform

ACTION="${1:-plan}"
STACKS=(00-vpc 10-sg 20-bastion 30-db 40-eks 50-acm 60-ingress-alb 70-ecr)
[ "$ACTION" = "destroy" ] && STACKS=($(printf '%s\n' "${STACKS[@]}" | tac))
[ -f backend.hcl ] || fail "terraform/backend.hcl not found (copy backend.hcl.example and set your state bucket)"

for stack in "${STACKS[@]}"; do
  log "=== ${stack}: terraform ${ACTION} ==="
  pushd "${stack}" >/dev/null
  terraform init -input=false -reconfigure -backend-config=../backend.hcl \
    -backend-config="key=${PROJECT_NAME}/${ENVIRONMENT}/${stack}.tfstate"
  case "${ACTION}" in
    plan)    terraform plan -input=false ;;
    apply)   terraform apply ;;
    destroy) terraform destroy ;;
    *)       fail "unknown action '${ACTION}' (plan|apply|destroy)" ;;
  esac
  popd >/dev/null
done
