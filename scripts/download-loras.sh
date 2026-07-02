#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

ensure_dirs
LORA_DIR="${MODELS_DIR}/loras"
DEST="${LORA_DIR}/pony_v6.safetensors"

if [[ -f "${DEST}" ]]; then
  log "Pony LoRA already present: ${DEST}"
  exit 0
fi

if [[ -n "${PONY_LORA_URL:-}" ]]; then
  log "Downloading Pony LoRA from PONY_LORA_URL..."
  curl -L --fail -o "${DEST}" "${PONY_LORA_URL}"
  log "Saved to ${DEST}"
  exit 0
fi

cat <<'EOF'
Pony Diffusion V6 XL LoRA is not hosted on Hugging Face with a stable direct URL.

Option A — set PONY_LORA_URL in .env to a direct .safetensors download link
Option B — download manually from Civitai and save as:
  models/loras/pony_v6.safetensors

Search: "Pony Diffusion V6 XL" on https://civitai.com
EOF

exit 0
