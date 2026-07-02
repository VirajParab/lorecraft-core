#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

activate_venv
ensure_dirs

log "Wan 2.2 setup (optional FX video — heavy VRAM/download)"

WAN_DIR="${VENDOR_DIR}/Wan2.2"
# Community ComfyUI wrappers exist; document manual model placement
mkdir -p "${MODELS_DIR}/wan"

cat <<EOF
Wan 2.2 weights are large (~24GB+ VRAM). Steps:

1. Install Wan ComfyUI nodes via ComfyUI Manager:
   Search "Wan" or "WanVideo" in Manager after: make serve-comfyui

2. Download Wan 2.2 weights per the model card instructions into:
   ${MODELS_DIR}/wan/

3. Set ENABLE_WAN=true in .env when ready.

See: https://huggingface.co/models?search=wan+video
EOF

# Optional: clone a known ComfyUI Wan wrapper if available
if [[ ! -d "${VENDOR_DIR}/ComfyUI/custom_nodes" ]]; then
  warn "Install ComfyUI first: make install-comfyui"
fi

log "Wan directory prepared at ${MODELS_DIR}/wan"
