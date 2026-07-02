#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

activate_venv
mkdir -p "${CORE_ROOT}/logs"

MODEL="${VLLM_MODEL:-Qwen/Qwen3-8B}"
PORT="${VLLM_PORT:-8000}"
MAX_LEN="${VLLM_MAX_MODEL_LEN:-32768}"
GPU_UTIL="${VLLM_GPU_MEMORY_UTILIZATION:-0.90}"

log "Starting vLLM on port ${PORT} with model ${MODEL}"

export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"
export HF_HOME="${CORE_ROOT}/hf_cache"

exec vllm serve "${MODEL}" \
  --host 0.0.0.0 \
  --port "${PORT}" \
  --max-model-len "${MAX_LEN}" \
  --gpu-memory-utilization "${GPU_UTIL}"
