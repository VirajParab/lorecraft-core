#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

activate_venv
ensure_dirs

MUSETALK_DIR="${VENDOR_DIR}/MuseTalk"
clone_repo "https://github.com/TMElyralab/MuseTalk.git" "${MUSETALK_DIR}"

log "Installing MuseTalk dependencies..."
if [[ -f "${MUSETALK_DIR}/requirements.txt" ]]; then
  pip_install -r "${MUSETALK_DIR}/requirements.txt"
fi

pip_install opencv-python-headless imageio imageio-ffmpeg

log "MuseTalk installed at ${MUSETALK_DIR}"
log "Download MuseTalk weights to: ${MODELS_DIR}/musetalk"
log "Use via ComfyUI workflow or vendor/MuseTalk inference scripts"
