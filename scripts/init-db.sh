#!/bin/bash
# Creates the least-privilege application user in RDS. Run it from the bastion host
# (the only host allowed to reach MySQL besides the EKS nodes). Idempotent.
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh
for tool in aws mysql jq sed; do need "$tool"; done

SECRET_JSON="$(aws secretsmanager get-secret-value --region "${AWS_REGION}" \
  --secret-id "${DB_SECRET_ID}" --query SecretString --output text)"
HOST="$(jq -r .host <<<"${SECRET_JSON}")"
PORT="$(jq -r .port <<<"${SECRET_JSON}")"
ADMIN_USER="$(jq -r .admin_username <<<"${SECRET_JSON}")"
ADMIN_PWD="$(jq -r .admin_password <<<"${SECRET_JSON}")"
APP_PWD="$(jq -r .app_password <<<"${SECRET_JSON}")"

log "Initialising the database on ${HOST}"
# The password is passed through MYSQL_PWD so it never appears in the process list.
sed "s/__APP_PASSWORD__/${APP_PWD}/g" ../backend/schema/backend.sql | \
  MYSQL_PWD="${ADMIN_PWD}" mysql -h "${HOST}" -P "${PORT}" -u "${ADMIN_USER}"
log "Done: user 'expense' has SELECT/INSERT/UPDATE/DELETE/CREATE on transactions.*"
