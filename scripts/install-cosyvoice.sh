#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

activate_venv
ensure_dirs

COSY_DIR="${VENDOR_DIR}/CosyVoice"
clone_repo "https://github.com/FunAudioLLM/CosyVoice.git" "${COSY_DIR}"

log "Pinning setuptools for CosyVoice / openai-whisper builds..."
pip_install "setuptools>=68,<82" wheel

log "Installing PyTorch (CosyVoice-compatible 2.3.x)..."
if have_gpu; then
  pip_install torch==2.3.1 torchaudio==2.3.1 \
    --index-url https://download.pytorch.org/whl/cu121 || \
    pip_install torch==2.3.1 torchaudio==2.3.1
else
  pip_install torch==2.3.1 torchaudio==2.3.1 \
    --index-url https://download.pytorch.org/whl/cpu
fi

log "Installing openai-whisper from GitHub (PyPI sdist fails on modern setuptools)..."
pip_install "git+https://github.com/openai/whisper.git"

if [[ -f "${COSY_DIR}/requirements.txt" ]]; then
  log "Installing CosyVoice inference dependencies (subset; skips training/UI extras)..."
  COSY_REQS="$(mktemp)"
  # Exclude packages that break LoreCraft core or are optional for TTS inference.
  grep -viE '^\s*(#|--extra-index-url)' "${COSY_DIR}/requirements.txt" | \
    grep -viE 'openai-whisper|deepspeed|tensorrt|^[[:space:]]*gradio|^[[:space:]]*fastapi|^[[:space:]]*fastapi-cli|^[[:space:]]*uvicorn|^[[:space:]]*torch==|^[[:space:]]*torchaudio==' \
    > "${COSY_REQS}" || true

  if [[ -s "${COSY_REQS}" ]]; then
    pip_install -r "${COSY_REQS}" || warn "Some CosyVoice deps failed (optional packages); TTS may still work"
  fi
  rm -f "${COSY_REQS}"
fi

log "Installing ONNX Runtime GPU (for CosyVoice)..."
if have_gpu; then
  pip_install --extra-index-url \
    "https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/onnxruntime-cuda-12/pypi/simple/" \
    onnxruntime-gpu==1.18.0 || pip_install onnxruntime-gpu || pip_install onnxruntime
else
  pip_install onnxruntime==1.18.0 || pip_install onnxruntime
fi

pip_install soundfile librosa

log "CosyVoice installed at ${COSY_DIR}"
log "Download model weights to: ${MODELS_DIR}/cosyvoice"
log "Start with: make serve-cosyvoice"
