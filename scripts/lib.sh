#!/bin/bash
# Shared helpers for the operational scripts.
set -euo pipefail

: "${PROJECT_NAME:=expense}"
: "${ENVIRONMENT:=dev}"
: "${AWS_REGION:=us-east-1}"
export PROJECT_NAME ENVIRONMENT AWS_REGION

CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}"
DB_SECRET_ID="${PROJECT_NAME}/${ENVIRONMENT}/db"

log()  { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
fail() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "'$1' is required but not installed"; }
