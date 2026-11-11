#!/usr/bin/env bash
# =============================================================================
# Infrastructure Provisioning Script
# =============================================================================
# Runs Terraform init + plan + apply for atlas-infra-base module.
# Exports tf-outputs.json for downstream jobs (build, deploy).
#
# Required env vars (set by GHA workflow):
#   ENVIRONMENT       — dev or staging
#   SUBSCRIPTION_ID   — Azure subscription ID
#
# Error handling: set -euo pipefail + trap writes error-context.json
# P5 pattern: Bash scripts (P3/P4 used PowerShell — shows range)
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
  echo "##[error]Script failed at line ${line_no} with exit code ${exit_code}"

  cat > "${REPO_ROOT}/error-context.json" <<EOF
{
  "script": "scripts/infra.sh",
  "step": "terraform-infra",
  "environment": "${ENVIRONMENT}",
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
  echo "##[error]ENVIRONMENT is not set. Expected: dev or staging"
  exit 1
fi

if [[ ! -f "${TFVARS_FILE}" ]]; then
  echo "##[error]tfvars file not found: ${TFVARS_FILE}"
  exit 1
fi

if [[ -z "${SUBSCRIPTION_ID:-}" ]]; then
  echo "##[error]SUBSCRIPTION_ID is not set"
  exit 1
fi

echo "=========================================="
echo "  Atlas-05 Infrastructure Provisioning"
echo "  Environment: ${ENVIRONMENT}"
echo "  tfvars: ${TFVARS_FILE}"
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

# --- Terraform Plan ---
echo ""
echo "##[section]Terraform Plan"
terraform plan \
  -var-file="${TFVARS_FILE}" \
  -var="subscription_id=${SUBSCRIPTION_ID}" \
  -out=tfplan

echo ""
echo "Resources planned:"
terraform show -no-color tfplan | grep -E "^  #|will be created|will be updated|will be destroyed" || echo "  (no changes)"

# --- Terraform Apply ---
echo ""
echo "##[section]Terraform Apply"
terraform apply tfplan

# --- Export Outputs ---
# Save non-sensitive outputs to JSON for downstream jobs.
# Uploaded as GitHub artifact by the workflow.
echo ""
echo "##[section]Exporting outputs to tf-outputs.json"

TF_OUTPUTS_FILE="${TF_DIR}/tf-outputs.json"

cat > "${TF_OUTPUTS_FILE}" <<EOF
{
  "resource_group_name": "$(terraform output -raw resource_group_name)",
  "acr_login_server": "$(terraform output -raw acr_login_server)",
  "acr_name": "$(terraform output -raw acr_name)",
  "aks_cluster_name": "$(terraform output -raw aks_cluster_name)"
}
EOF

echo "Outputs saved to: ${TF_OUTPUTS_FILE}"
cat "${TF_OUTPUTS_FILE}" | python3 -m json.tool

echo ""
echo "##[section]Infrastructure provisioning complete"