#!/bin/bash
# Reads the application DB credentials from AWS Secrets Manager and stores them in the
# Kubernetes Secret "backend-db" (namespace "expense") consumed by the backend Deployment.
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh
for tool in aws kubectl jq; do need "$tool"; done

SECRET_JSON="$(aws secretsmanager get-secret-value --region "${AWS_REGION}" \
  --secret-id "${DB_SECRET_ID}" --query SecretString --output text)"

kubectl create namespace expense --dry-run=client -o yaml | kubectl apply -f -
kubectl -n expense create secret generic backend-db \
  --from-literal=DB_USER="$(jq -r .app_username <<<"${SECRET_JSON}")" \
  --from-literal=DB_PWD="$(jq -r .app_password <<<"${SECRET_JSON}")" \
  --dry-run=client -o yaml | kubectl apply -f -
log "Secret expense/backend-db is up to date (DB host: $(jq -r .host <<<"${SECRET_JSON}"))"
