#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

activate_venv

ensure_nccl_matches_torch

if python -c "import torch; print('torch', torch.__version__)"; then
  log "NCCL / PyTorch import OK."
else
  die "torch still fails to import. Try: make repair-gpu-stack"
fi
