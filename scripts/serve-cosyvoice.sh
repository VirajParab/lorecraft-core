#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

activate_venv

COSY_DIR="${VENDOR_DIR}/CosyVoice"
[[ -d "${COSY_DIR}" ]] || die "CosyVoice not installed. Run: make install-cosyvoice"

PORT="${COSYVOICE_PORT:-9001}"
MODEL_DIR="${COSYVOICE_MODEL_DIR:-${MODELS_DIR}/cosyvoice}"

log "Starting CosyVoice wrapper on port ${PORT}"
log "Model dir: ${MODEL_DIR}"

cd "${CORE_ROOT}"
export PYTHONPATH="${COSY_DIR}:${PYTHONPATH:-}"

# Thin wrapper — extend with CosyVoice FastAPI when models are downloaded
exec python -m lorecraft_core.services.cosyvoice_server \
  --host 0.0.0.0 \
  --port "${PORT}" \
  --model-dir "${MODEL_DIR}"
