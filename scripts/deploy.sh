#!/usr/bin/env bash
# =============================================================================
# Deploy Script — Helm upgrade + rollout wait + smoke test
# =============================================================================
# 1. Read cluster details from tf-outputs.json
# 2. Get AKS credentials
# 3. Helm upgrade --install with per-env values
# 4. Wait for rollout
# 5. Smoke test via kubectl exec → curl /health
#
# Required env vars:
#   ENVIRONMENT   — dev or staging
#   IMAGE_NAME    — e.g., atlas-platform-app
#   IMAGE_TAG     — e.g., github.run_number
#
# P4 retro fix: re-query pod name AFTER rollout + kubectl wait before exec
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- Error handler ---
on_error() {
  local exit_code=$?
  local line_no=$1
  echo "##[error]Deploy script failed at line ${line_no} with exit code ${exit_code}"

  cat > "${REPO_ROOT}/error-context.json" <<EOF
{
  "script": "scripts/deploy.sh",
  "step": "helm-deploy",
  "environment": "${ENVIRONMENT:-unknown}",
  "image_tag": "${IMAGE_TAG:-unknown}",
  "line": ${line_no},
  "exit_code": ${exit_code},
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
  exit $exit_code
}
trap 'on_error $LINENO' ERR

# --- Validate inputs ---
for var in ENVIRONMENT IMAGE_NAME IMAGE_TAG; do
  if [[ -z "${!var:-}" ]]; then
    echo "##[error]${var} is not set"
    exit 1
  fi
done

# --- Read cluster details ---
TF_OUTPUTS="${REPO_ROOT}/tf-outputs/tf-outputs.json"
if [[ ! -f "${TF_OUTPUTS}" ]]; then
  echo "##[error]tf-outputs.json not found at ${TF_OUTPUTS}"
  exit 1
fi

RG_NAME=$(python3 -c "import json; print(json.load(open('${TF_OUTPUTS}'))['resource_group_name'])")
AKS_NAME=$(python3 -c "import json; print(json.load(open('${TF_OUTPUTS}'))['aks_cluster_name'])")
ACR_LOGIN_SERVER=$(python3 -c "import json; print(json.load(open('${TF_OUTPUTS}'))['acr_login_server'])")

NAMESPACE="${ENVIRONMENT}"
RELEASE_NAME="atlas-platform-${ENVIRONMENT}"
CHART_PATH="${REPO_ROOT}/charts/atlas-platform"
VALUES_FILE="${CHART_PATH}/values-${ENVIRONMENT}.yaml"
FULL_IMAGE="${ACR_LOGIN_SERVER}/${IMAGE_NAME}"

echo "=========================================="
echo "  Atlas-05 Helm Deploy"
echo "  Environment: ${ENVIRONMENT}"
echo "  Namespace:   ${NAMESPACE}"
echo "  Image:       ${FULL_IMAGE}:${IMAGE_TAG}"
echo "  Cluster:     ${AKS_NAME}"
echo "=========================================="

# --- Get AKS credentials ---
echo ""
echo "##[section]Get AKS Credentials"
az aks get-credentials \
  --resource-group "${RG_NAME}" \
  --name "${AKS_NAME}" \
  --overwrite-existing

# --- Create namespace if not exists ---
echo ""
echo "##[section]Ensure namespace: ${NAMESPACE}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# --- Helm Upgrade ---
echo ""
echo "##[section]Helm Upgrade"
helm upgrade --install "${RELEASE_NAME}" "${CHART_PATH}" \
  --namespace "${NAMESPACE}" \
  --values "${VALUES_FILE}" \
  --set image.repository="${FULL_IMAGE}" \
  --set image.tag="${IMAGE_TAG}" \
  --wait \
  --timeout 5m

# --- Rollout Status ---
echo ""
echo "##[section]Rollout Status"
kubectl rollout status deployment/"${RELEASE_NAME}" \
  --namespace "${NAMESPACE}" \
  --timeout=120s

# --- Wait for pod ready (P4 retro fix) ---
echo ""
echo "##[section]Wait for pod ready"
kubectl wait pod \
  --for=condition=ready \
  --selector="app.kubernetes.io/instance=${RELEASE_NAME}" \
  --namespace "${NAMESPACE}" \
  --timeout=90s

# --- Smoke Test ---
echo ""
echo "##[section]Smoke Test"

# Re-query pod name AFTER rollout (P4 retro fix — pod name changes after upgrade)
POD_NAME=$(kubectl get pods \
  --namespace "${NAMESPACE}" \
  --selector="app.kubernetes.io/instance=${RELEASE_NAME}" \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}')

POD_NAME=$(echo "${POD_NAME}" | tr -d '[:space:]')

echo "Testing pod: ${POD_NAME}"

HEALTH_RESPONSE=$(kubectl exec "${POD_NAME}" \
  --namespace "${NAMESPACE}" \
  -- python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/health').read().decode())" 2>&1)

HEALTH_RESPONSE=$(echo "${HEALTH_RESPONSE}" | tr -d '[:space:]')

if echo "${HEALTH_RESPONSE}" | grep -q '"status":"healthy"'; then
  echo "Smoke test PASSED: ${HEALTH_RESPONSE}"
else
  echo "##[error]Smoke test FAILED"
  echo "Response: ${HEALTH_RESPONSE}"
  exit 1
fi

echo ""
echo "##[section]Deploy complete — ${ENVIRONMENT}"
echo "  Release: ${RELEASE_NAME}"
echo "  Namespace: ${NAMESPACE}"
echo "  Pod: ${POD_NAME}"