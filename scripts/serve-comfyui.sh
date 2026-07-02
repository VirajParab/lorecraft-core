#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

activate_venv

COMFY_DIR="${VENDOR_DIR}/ComfyUI"
[[ -d "${COMFY_DIR}" ]] || die "ComfyUI not installed. Run: make install-comfyui"

HOST="${COMFYUI_HOST:-127.0.0.1}"
PORT="${COMFYUI_PORT:-8188}"
EXTRA="${COMFYUI_EXTRA_ARGS:-}"

log "Starting ComfyUI on http://${HOST}:${PORT}"

export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"

cd "${COMFY_DIR}"
exec python main.py --listen "${HOST}" --port "${PORT}" ${EXTRA}
