#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

activate_venv

log "Restoring vLLM PyTorch stack (fixes CosyVoice or other installs that downgraded torch)..."
pip_install --force-reinstall vllm

verify_gpu_stack || die "GPU stack repair failed. See errors above."

log "GPU stack restored. Re-run: make health"
