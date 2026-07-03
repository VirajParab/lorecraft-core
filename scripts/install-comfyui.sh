#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

activate_venv
ensure_dirs

COMFY_DIR="${VENDOR_DIR}/ComfyUI"
clone_repo "https://github.com/comfyanonymous/ComfyUI.git" "${COMFY_DIR}"

log "Installing ComfyUI Python dependencies..."
pip_install -r "${COMFY_DIR}/requirements.txt"

bash "${SCRIPT_DIR}/pin-numpy-opencv.sh"

# Symlink model dirs into ComfyUI
mkdir -p "${COMFY_DIR}/models/checkpoints" "${COMFY_DIR}/models/loras" "${COMFY_DIR}/models/vae" "${COMFY_DIR}/models/clip"

link_model_dir() {
  local src="${MODELS_DIR}/$1"
  local dest="${COMFY_DIR}/models/$1"
  mkdir -p "${src}"
  if [[ ! -e "${dest}" ]]; then
    ln -sf "${src}" "${dest}"
    log "Linked ${dest} -> ${src}"
  fi
}

link_model_dir checkpoints
link_model_dir loras
link_model_dir vae
link_model_dir clip

log "ComfyUI installed at ${COMFY_DIR}"
log "Install custom nodes: make install-comfyui-nodes"
log "Start with: make serve-comfyui"
