#!/usr/bin/env bash
# =============================================================================
# Build, Scan, and Push Script
# =============================================================================
# 1. Read ACR details from tf-outputs.json (downloaded GHA artifact)
# 2. Docker build (multi-stage, non-root)
# 3. Trivy scan — fail on CRITICAL (zero tolerance)
# 4. SBOM generation (trivy --format spdx-json)
# 5. ACR login + push (same step — token expiry fix from P4 retro)
#
# Required env vars (set by GHA workflow):
#   IMAGE_NAME  — e.g., atlas-platform-app
#   IMAGE_TAG   — e.g., github.run_number
#
# Reads: tf-outputs.json (from infra job artifact)
# Produces: sbom.json, trivy-report.json (uploaded as GHA artifacts)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- Error handler ---
on_error() {
  local exit_code=$?
  local line_no=$1
  echo "##[error]Build script failed at line ${line_no} with exit code ${exit_code}"

  cat > "${REPO_ROOT}/error-context.json" <<EOF
{
  "script": "scripts/build.sh",
  "step": "build-scan-push",
  "image_name": "${IMAGE_NAME:-unknown}",
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
if [[ -z "${IMAGE_NAME:-}" ]]; then
  echo "##[error]IMAGE_NAME is not set"
  exit 1
fi

if [[ -z "${IMAGE_TAG:-}" ]]; then
  echo "##[error]IMAGE_TAG is not set"
  exit 1
fi

# --- Read ACR details from terraform outputs ---
TF_OUTPUTS="${REPO_ROOT}/tf-outputs/tf-outputs.json"
if [[ ! -f "${TF_OUTPUTS}" ]]; then
  echo "##[error]tf-outputs.json not found at ${TF_OUTPUTS}"
  echo "Ensure infra job uploaded the terraform-outputs artifact"
  exit 1
fi

ACR_NAME=$(python3 -c "import json; print(json.load(open('${TF_OUTPUTS}'))['acr_name'])")
ACR_LOGIN_SERVER=$(python3 -c "import json; print(json.load(open('${TF_OUTPUTS}'))['acr_login_server'])")

FULL_IMAGE="${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "=========================================="
echo "  Atlas-05 Build + Scan + Push"
echo "  Image: ${FULL_IMAGE}"
echo "  ACR:   ${ACR_NAME}"
echo "=========================================="

# --- Docker Build ---
echo ""
echo "##[section]Docker Build"
docker build \
  -t "${FULL_IMAGE}" \
  -f "${REPO_ROOT}/Dockerfile" \
  "${REPO_ROOT}"

echo "Image size:"
docker images "${FULL_IMAGE}" --format "  {{.Repository}}:{{.Tag}} — {{.Size}}"

# --- Trivy Scan ---
echo ""
echo "##[section]Trivy Vulnerability Scan"
trivy image \
  --exit-code 1 \
  --severity CRITICAL \
  --no-progress \
  --format json \
  --output "${REPO_ROOT}/trivy-report.json" \
  "${FULL_IMAGE}"

echo "Trivy scan passed — zero CRITICAL vulnerabilities"

# Show summary (HIGH + CRITICAL counts)
echo ""
echo "Full scan summary (informational):"
trivy image \
  --exit-code 0 \
  --severity HIGH,CRITICAL \
  --no-progress \
  "${FULL_IMAGE}" 2>&1 | tail -20

# --- SBOM Generation ---
echo ""
echo "##[section]SBOM Generation (SPDX)"
trivy image \
  --format spdx-json \
  --output "${REPO_ROOT}/sbom.json" \
  --no-progress \
  "${FULL_IMAGE}"

SBOM_PACKAGES=$(python3 -c "import json; d=json.load(open('${REPO_ROOT}/sbom.json')); print(len(d.get('packages',[])))" 2>/dev/null || echo "unknown")
echo "SBOM generated: ${SBOM_PACKAGES} packages cataloged"

# --- ACR Login + Push (same step — token expiry fix) ---
echo ""
echo "##[section]ACR Login + Push"
az acr login --name "${ACR_NAME}"
docker push "${FULL_IMAGE}"

echo ""
echo "##[section]Build complete"
echo "  Image pushed: ${FULL_IMAGE}"
echo "  Trivy: PASS (zero CRITICAL)"
echo "  SBOM: ${SBOM_PACKAGES} packages"