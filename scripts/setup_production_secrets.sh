#!/usr/bin/env bash
# ==============================================================================
# TruthWorld: Google Cloud Secret Manager Production Provisioning Script
# Project: truthworld-1
# Region: asia-south1
# ==============================================================================

set -euo pipefail

PROJECT_ID="${1:-truthworld-1}"
CASHFREE_APP_ID="${2:-}"
CASHFREE_SECRET_KEY="${3:-}"
ASSEMBLYAI_KEY="${4:-}"
ELEVENLABS_API_KEY="${5:-}"
SARVAM_API_KEY="${6:-}"
INDEXNOW_KEY="${7:-truthworld-indexnow-key-2026}"

echo "=========================================================="
echo " TruthWorld Production Secret Manager Setup"
echo " Target Project: ${PROJECT_ID}"
echo "=========================================================="

if [ -z "${CASHFREE_APP_ID}" ]; then
  read -r -p "Enter Cashfree Production Client ID (CASHFREE_APP_ID): " CASHFREE_APP_ID
fi

if [ -z "${CASHFREE_SECRET_KEY}" ]; then
  read -r -s -p "Enter Cashfree Production Secret Key (CASHFREE_SECRET_KEY): " CASHFREE_SECRET_KEY
  echo ""
fi

set_gcp_secret() {
  local secret_name="$1"
  local secret_value="$2"

  if [ -z "${secret_value}" ]; then
    echo "[-] Skipping ${secret_name} (empty value)"
    return
  fi

  echo "[*] Checking secret '${secret_name}' in project '${PROJECT_ID}'..."

  if ! gcloud secrets describe "${secret_name}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    echo "[+] Creating secret '${secret_name}'..."
    gcloud secrets create "${secret_name}" --replication-policy="automatic" --project="${PROJECT_ID}"
  fi

  echo "[+] Adding new secret version for '${secret_name}'..."
  printf "%s" "${secret_value}" | gcloud secrets versions add "${secret_name}" --data-file=- --project="${PROJECT_ID}"

  local project_number
  project_number=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")
  local compute_sa="${project_number}-compute@developer.gserviceaccount.com"
  local appengine_sa="${PROJECT_ID}@appspot.gserviceaccount.com"

  gcloud secrets add-iam-policy-binding "${secret_name}" \
    --member="serviceAccount:${compute_sa}" \
    --role="roles/secretmanager.secretAccessor" \
    --project="${PROJECT_ID}" >/dev/null 2>&1 || true

  gcloud secrets add-iam-policy-binding "${secret_name}" \
    --member="serviceAccount:${appengine_sa}" \
    --role="roles/secretmanager.secretAccessor" \
    --project="${PROJECT_ID}" >/dev/null 2>&1 || true

  echo "[✓] '${secret_name}' successfully configured."
}

set_gcp_secret "CASHFREE_APP_ID" "${CASHFREE_APP_ID}"
set_gcp_secret "CASHFREE_SECRET_KEY" "${CASHFREE_SECRET_KEY}"

if [ -n "${ASSEMBLYAI_KEY}" ]; then
  set_gcp_secret "ASSEMBLYAI_KEY" "${ASSEMBLYAI_KEY}"
fi

if [ -n "${ELEVENLABS_API_KEY}" ]; then
  set_gcp_secret "ELEVENLABS_API_KEY" "${ELEVENLABS_API_KEY}"
fi

if [ -n "${SARVAM_API_KEY}" ]; then
  set_gcp_secret "SARVAM_API_KEY" "${SARVAM_API_KEY}"
fi

if [ -n "${INDEXNOW_KEY}" ]; then
  set_gcp_secret "INDEXNOW_KEY" "${INDEXNOW_KEY}"
fi

echo "=========================================================="
echo " [✓] All production secrets provisioned successfully!"
echo " Next step: Deploy functions with: cd functions && npm run deploy"
echo "=========================================================="
