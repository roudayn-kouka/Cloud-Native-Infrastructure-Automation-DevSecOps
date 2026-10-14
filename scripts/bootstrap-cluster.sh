#!/bin/bash
# One-time cluster bootstrap, run from the bastion (or any host that can reach the EKS API).
#   1. kubeconfig + gp3 StorageClass + metrics-server
#   2. AWS Load Balancer Controller (IRSA role created by terraform/40-eks)
#   3. Namespaces + secrets that must exist before the apps start
#   4. ArgoCD + the "root" app-of-apps (which then deploys the app and the monitoring stack)
#
# Usage: ./bootstrap-cluster.sh            (the IRSA role ARN is read from SSM; override with LB_CONTROLLER_ROLE_ARN)
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh
for tool in aws kubectl helm jq; do need "$tool"; done

REPO_ROOT="$(cd .. && pwd)"
LB_CONTROLLER_ROLE_ARN="${LB_CONTROLLER_ROLE_ARN:-$(aws ssm get-parameter --region "${AWS_REGION}" \
  --name "/${PROJECT_NAME}/${ENVIRONMENT}/lb_controller_role_arn" --query Parameter.Value --output text)}"

log "Configuring kubectl for ${CLUSTER_NAME}"
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}"
kubectl get nodes

log "Applying the gp3 StorageClass"
kubectl delete storageclass gp2 --ignore-not-found >/dev/null 2>&1 || true
kubectl apply -f "${REPO_ROOT}/gitops/platform/storageclass-gp3.yaml"

log "Installing metrics-server (needed by the HPAs)"
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ >/dev/null
helm repo update >/dev/null
helm upgrade --install metrics-server metrics-server/metrics-server -n kube-system --wait

log "Installing the AWS Load Balancer Controller"
VPC_ID="$(aws ssm get-parameter --region "${AWS_REGION}" --name "/${PROJECT_NAME}/${ENVIRONMENT}/vpc_id" --query Parameter.Value --output text)"
helm repo add eks https://aws.github.io/eks-charts >/dev/null
helm repo update >/dev/null
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set region="${AWS_REGION}" \
  --set vpcId="${VPC_ID}" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set-string serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${LB_CONTROLLER_ROLE_ARN}" \
  --wait

log "Creating namespaces and secrets"
kubectl create namespace expense --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
"${REPO_ROOT}/scripts/create-db-secret.sh"
if ! kubectl -n monitoring get secret grafana-admin >/dev/null 2>&1; then
  GRAFANA_PASSWORD="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)"
  kubectl -n monitoring create secret generic grafana-admin \
    --from-literal=admin-user=admin --from-literal=admin-password="${GRAFANA_PASSWORD}"
  log "Grafana admin password (store it in your password manager): ${GRAFANA_PASSWORD}"
fi

log "Installing ArgoCD"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo update >/dev/null
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace --wait

log "Registering the AppProject and the root application"
kubectl apply -f "${REPO_ROOT}/gitops/argocd/project.yaml"
kubectl apply -f "${REPO_ROOT}/gitops/argocd/root-app.yaml"

cat <<MSG

Bootstrap finished.
  ArgoCD UI      : kubectl -n argocd port-forward svc/argocd-server 8081:443   ->  https://localhost:8081
  ArgoCD password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
  Grafana        : kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
  Prometheus     : kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
MSG
