#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

COMFY_DIR="${VENDOR_DIR}/ComfyUI"
CUSTOM_NODES="${COMFY_DIR}/custom_nodes"

[[ -d "${COMFY_DIR}" ]] || die "ComfyUI not installed. Run: make install-comfyui"

mkdir -p "${CUSTOM_NODES}"

install_node() {
  local url="$1"
  local name="$2"
  clone_repo "${url}" "${CUSTOM_NODES}/${name}"
}

log "Installing ComfyUI custom nodes..."

install_node "https://github.com/ltdrdata/ComfyUI-Manager.git" "ComfyUI-Manager"
install_node "https://github.com/cubiq/ComfyUI_IPAdapter_plus.git" "ComfyUI_IPAdapter_plus"
install_node "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" "ComfyUI-VideoHelperSuite"
install_node "https://github.com/kijai/ComfyUI-KJNodes.git" "ComfyUI-KJNodes"

# Background removal for transparent sprite PNGs (Jcd1230/ComfyUI-rembg was removed from GitHub)
install_node "https://github.com/1038lab/ComfyUI-RMBG.git" "ComfyUI-RMBG" || warn "ComfyUI-RMBG optional install failed"

log "Custom nodes installed."
log "Open ComfyUI Manager in the UI to install any missing dependencies."

bash "${SCRIPT_DIR}/pin-numpy-opencv.sh"
