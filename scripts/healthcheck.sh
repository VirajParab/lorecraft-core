#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

check_port() {
  local name="$1"
  local port="$2"
  if curl -sf "http://127.0.0.1:${port}/" >/dev/null 2>&1 || \
     curl -sf "http://127.0.0.1:${port}/health" >/dev/null 2>&1 || \
     curl -sf "http://127.0.0.1:${port}/v1/models" >/dev/null 2>&1; then
    printf '  \033[32m✓\033[0m %-20s http://127.0.0.1:%s\n' "${name}" "${port}"
    return 0
  fi
  printf '  \033[31m✗\033[0m %-20s http://127.0.0.1:%s (not running)\n' "${name}" "${port}"
  return 1
}

log "LoreCraft Core health check"
echo ""

FAIL=0

[[ -d "${VENV_DIR}" ]] && printf '  \033[32m✓\033[0m Python venv\n' || { printf '  \033[31m✗\033[0m Python venv\n'; FAIL=1; }
[[ -d "${VENDOR_DIR}/ComfyUI" ]] && printf '  \033[32m✓\033[0m ComfyUI\n' || printf '  \033[33m!\033[0m ComfyUI (make install-comfyui)\n'
[[ -d "${VENDOR_DIR}/CosyVoice" ]] && printf '  \033[32m✓\033[0m CosyVoice\n' || printf '  \033[33m!\033[0m CosyVoice (make install-cosyvoice)\n'
[[ -d "${VENDOR_DIR}/MuseTalk" ]] && printf '  \033[32m✓\033[0m MuseTalk\n' || printf '  \033[33m!\033[0m MuseTalk (make install-musetalk)\n'
command -v ffmpeg >/dev/null && printf '  \033[32m✓\033[0m FFmpeg\n' || { printf '  \033[31m✗\033[0m FFmpeg\n'; FAIL=1; }
have_gpu && printf '  \033[32m✓\033[0m NVIDIA GPU\n' || printf '  \033[33m!\033[0m No GPU detected\n'

echo ""
echo "Services:"
check_port "vLLM" "${VLLM_PORT:-8000}" || true
check_port "ComfyUI" "${COMFYUI_PORT:-8188}" || true

echo ""
if [[ "${FAIL}" -eq 0 ]]; then
  log "Core installation looks OK."
else
  warn "Some required components missing. Run: make install-all"
fi
