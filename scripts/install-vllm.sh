#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

activate_venv
ensure_dirs

log "Installing vLLM + PyTorch (CUDA required for GPU inference)..."

if ! have_gpu; then
  die "NVIDIA GPU not detected (nvidia-smi failed). Use a CUDA GPU pod, then re-run: make install-vllm"
fi

log "GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || nvidia-smi -L | head -1)"

pip_install vllm

ensure_nccl_matches_torch

verify_gpu_stack || die "vLLM / PyTorch install did not complete successfully."

log "vLLM installed."
log "Default model: ${VLLM_MODEL:-Qwen/Qwen3-8B}"
log "Start with: make serve-vllm"
