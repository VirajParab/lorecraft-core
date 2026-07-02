#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

activate_venv
ensure_dirs

COSY_DIR="${VENDOR_DIR}/CosyVoice"
clone_repo "https://github.com/FunAudioLLM/CosyVoice.git" "${COSY_DIR}"

log "Installing CosyVoice dependencies..."
if [[ -f "${COSY_DIR}/requirements.txt" ]]; then
  pip_install -r "${COSY_DIR}/requirements.txt"
fi

# CosyVoice often needs onnxruntime and torch — ensure torch if GPU present
if have_gpu; then
  pip_install torch torchaudio --index-url https://download.pytorch.org/whl/cu124 || pip_install torch torchaudio
else
  pip_install torch torchaudio --index-url https://download.pytorch.org/whl/cpu || pip_install torch torchaudio
fi

pip_install onnxruntime soundfile librosa

log "CosyVoice installed at ${COSY_DIR}"
log "Download model weights to: ${MODELS_DIR}/cosyvoice"
log "Start with: make serve-cosyvoice"
