#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

activate_venv

log "Restoring vLLM PyTorch stack (fixes CosyVoice or other installs that downgraded torch)..."
pip_install --force-reinstall vllm

python - <<'PY'
import torch
import vllm

print(f"torch {torch.__version__}")
print(f"vllm {vllm.__version__}")
PY

log "GPU stack restored. Re-run: make health"
