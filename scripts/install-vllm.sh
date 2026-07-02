#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

activate_venv
ensure_dirs

log "Installing vLLM (CUDA required for GPU inference)..."

if have_gpu; then
  pip_install vllm
else
  warn "No NVIDIA GPU detected. Installing vLLM CPU build may fail — skip with: make install-python only"
  pip_install vllm || warn "vLLM install failed without GPU. Install on a GPU machine."
fi

log "vLLM installed."
log "Default model: ${VLLM_MODEL:-Qwen/Qwen3-8B}"
log "Start with: make serve-vllm"
