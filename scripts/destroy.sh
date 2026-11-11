#!/usr/bin/env bash
# =============================================================================
# Destroy Script — Terraform destroy + cleanup
# =============================================================================
# 1. Terraform destroy (infra — AKS, ACR, VNet, RG)
# 2. Verify resource group is gone
#
# Note: This does NOT destroy the OIDC bootstrap (separate state).
#       OIDC trust stays alive for future runs.
#       To destroy OIDC: run ADO pipeline with action=destroy.
#
# Required env vars:
#   ENVIRONMENT     — dev or staging
#   SUBSCRIPTION_ID — Azure subscription ID
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform/infra"
TFVARS_FILE="${TF_DIR}/environments/${ENVIRONMENT}.tfvars"

# --- Error handler ---
on_error() {
  local exit_code=$?
  local line_no=$1
  echo "##[error]Destroy script failed at line ${line_no} with exit code ${exit_code}"

  cat > "${REPO_ROOT}/error-context.json" <<EOF
{
  "script": "scripts/destroy.sh",
  "step": "terraform-destroy",
  "environment": "${ENVIRONMENT:-unknown}",
  "line": ${line_no},
  "exit_code": ${exit_code},
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
  exit $exit_code
}
trap 'on_error $LINENO' ERR

# --- Validate inputs ---
if [[ -z "${ENVIRONMENT:-}" ]]; then
  echo "##[error]ENVIRONMENT is not set"
  exit 1
fi

if [[ ! -f "${TFVARS_FILE}" ]]; then
  echo "##[error]tfvars not found: ${TFVARS_FILE}"
  exit 1
fi

if [[ -z "${SUBSCRIPTION_ID:-}" ]]; then
  echo "##[error]SUBSCRIPTION_ID is not set"
  exit 1
fi

echo "=========================================="
echo "  Atlas-05 Infrastructure Destroy"
echo "  Environment: ${ENVIRONMENT}"
echo "=========================================="

# --- Terraform Init ---
echo ""
echo "##[section]Terraform Init"
cd "${TF_DIR}"

terraform init \
  -backend-config="resource_group_name=rg-atlas-tfstate" \
  -backend-config="storage_account_name=atlastfstate2606" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=atlas-05.tfstate" \
  -backend-config="use_oidc=true"

# --- Terraform Destroy ---
echo ""
echo "##[section]Terraform Destroy"
terraform destroy \
  -var-file="${TFVARS_FILE}" \
  -var="subscription_id=${SUBSCRIPTION_ID}" \
  -auto-approve

# --- Verify ---
echo ""
echo "##[section]Verify resource group deleted"
RG_NAME="rg-atlas-05-${ENVIRONMENT}"

if az group show --name "${RG_NAME}" &> /dev/null; then
  echo "##[warning]Resource group ${RG_NAME} still exists — may take a few minutes"
else
  echo "Resource group ${RG_NAME} confirmed deleted"
fi

echo ""
echo "##[section]Infrastructure destroy complete"
echo "  Note: OIDC trust (atlas-05-oidc.tfstate) is NOT destroyed."
echo "  To destroy OIDC: run ADO pipeline with action=destroy."