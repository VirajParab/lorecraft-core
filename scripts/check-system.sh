#!/usr/bin/env bash
# Validate machine hardware, dependencies, and LoreCraft stack readiness.
set -uo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

PASS=0
WARN=0
FAIL=0

# status labels (prefixed to avoid clashing with common.sh helpers)
check_pass() { printf '  \033[32m✓ PASS\033[0m  %-28s %s\n' "$1" "$2"; PASS=$((PASS + 1)); }
check_warn() { printf '  \033[33m! WARN\033[0m  %-28s %s\n' "$1" "$2"; WARN=$((WARN + 1)); }
check_fail() { printf '  \033[31m✗ FAIL\033[0m  %-28s %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }
section() { echo ""; echo "── $1 ──"; }

# Replace shorthand calls below via sed — use check_* names throughout
pass() { check_pass "$@"; }
warn() { check_warn "$@"; }
fail() { check_fail "$@"; }

# Resolve absolute paths
VENDOR_DIR="$(cd "${VENDOR_DIR}" 2>/dev/null && pwd || echo "${CORE_ROOT}/vendor")"
MODELS_DIR="$(cd "${MODELS_DIR}" 2>/dev/null && pwd || echo "${CORE_ROOT}/models")"
VENV_DIR="$(cd "${VENV_DIR}" 2>/dev/null && pwd || echo "${CORE_ROOT}/.venv")"
HF_HOME="${HF_HOME:-${CORE_ROOT}/hf_cache}"
VLLM_MODEL="${VLLM_MODEL:-Qwen/Qwen3-8B}"
ENABLE_WAN="${ENABLE_WAN:-false}"

# ─── Helpers ─────────────────────────────────────────────────────────────────

version_ge() {
  # version_ge 3.10 3.10.13
  local min="$1" cur="$2"
  printf '%s\n%s\n' "$min" "$cur" | sort -V -C 2>/dev/null
}

disk_free_gb() {
  local path="$1"
  df -BG "$path" 2>/dev/null | awk 'NR==2 { gsub("G","",$4); print $4 }' || echo "0"
}

ram_total_gb() {
  free -g 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "0"
}

dir_size_gb() {
  local path="$1"
  if [[ -d "$path" ]]; then
    du -sBG "$path" 2>/dev/null | awk '{ gsub("G","",$1); print $1 }' || echo "0"
  else
    echo "0"
  fi
}

dir_has_files() {
  local path="$1"
  [[ -d "$path" ]] && [[ -n "$(find "$path" -mindepth 1 -maxdepth 3 -type f 2>/dev/null | head -1)" ]]
}

port_in_use() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -tlnH "( sport = :${port} )" 2>/dev/null | grep -q .
  elif command -v lsof >/dev/null 2>&1; then
    lsof -iTCP:"${port}" -sTCP:LISTEN -t >/dev/null 2>&1
  else
    return 1
  fi
}

recommended_vram_gb() {
  local model="$1"
  case "$model" in
    *32B*|*70B*) echo 24 ;;
    *8B*|*7B*|*14B*) echo 16 ;;
    *) echo 16 ;;
  esac
}

# ─── Report header ───────────────────────────────────────────────────────────

echo ""
log "LoreCraft Core — system configuration check"
echo "Host: $(hostname 2>/dev/null || echo unknown)  |  Core: ${CORE_ROOT}"
echo "Model profile (.env): ${VLLM_MODEL}  |  Wan FX: ${ENABLE_WAN}"

# ─── 1. Operating system ─────────────────────────────────────────────────────

section "Operating system"

OS_ID="unknown"
if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  OS_ID="${NAME:-unknown} ${VERSION_ID:-}"
  pass "OS" "${OS_ID}"
else
  warn "OS" "Cannot read /etc/os-release"
fi

if [[ "$(uname -s)" == "Linux" ]]; then
  pass "Platform" "Linux ($(uname -m))"
else
  warn "Platform" "$(uname -s) — Linux recommended for GPU stack"
fi

KERNEL="$(uname -r)"
pass "Kernel" "${KERNEL}"

# ─── 2. CPU & memory ─────────────────────────────────────────────────────────

section "CPU & memory"

CPU_THREADS="$(nproc 2>/dev/null || echo 0)"
if [[ "${CPU_THREADS}" -ge 8 ]]; then
  pass "CPU threads" "${CPU_THREADS} (≥8 recommended)"
elif [[ "${CPU_THREADS}" -ge 4 ]]; then
  warn "CPU threads" "${CPU_THREADS} — 8+ recommended for compositor + services"
else
  fail "CPU threads" "${CPU_THREADS} — too few for comfortable dev"
fi

RAM_GB="$(ram_total_gb)"
if [[ "${RAM_GB}" -ge 32 ]]; then
  pass "RAM" "${RAM_GB} GB (≥32 GB recommended)"
elif [[ "${RAM_GB}" -ge 16 ]]; then
  warn "RAM" "${RAM_GB} GB — workable; 32+ GB recommended for full stack"
else
  fail "RAM" "${RAM_GB} GB — 16 GB minimum, 32+ GB recommended"
fi

# ─── 3. Disk ─────────────────────────────────────────────────────────────────

section "Disk"

FREE_GB="$(disk_free_gb "${CORE_ROOT}")"
MODELS_USED_GB="$(dir_size_gb "${MODELS_DIR}")"
HF_USED_GB="$(dir_size_gb "${HF_HOME}")"

if [[ "${FREE_GB}" -ge 100 ]]; then
  pass "Free disk" "${FREE_GB} GB free on $(df -h "${CORE_ROOT}" | awk 'NR==2 {print $1}')"
elif [[ "${FREE_GB}" -ge 50 ]]; then
  warn "Free disk" "${FREE_GB} GB free — 100+ GB recommended for models"
else
  fail "Free disk" "${FREE_GB} GB free — need ~50 GB min, 100+ GB for full models"
fi

pass "Models dir" "${MODELS_USED_GB} GB used at ${MODELS_DIR}"
pass "HF cache" "${HF_USED_GB} GB used at ${HF_HOME}"

# ─── 4. GPU & CUDA ───────────────────────────────────────────────────────────

section "GPU & CUDA"

TOTAL_VRAM_MB=0
GPU_COUNT=0

if have_gpu; then
  while IFS= read -r line; do
    GPU_COUNT=$((GPU_COUNT + 1))
    pass "GPU ${GPU_COUNT}" "${line}"
  done < <(nvidia-smi --query-gpu=index,name,memory.total,driver_version --format=csv,noheader 2>/dev/null | sed 's/^/  /')

  TOTAL_VRAM_MB="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | awk '{s+=$1} END {print s+0}')"
  TOTAL_VRAM_GB=$(( TOTAL_VRAM_MB / 1024 ))
  CUDA_VER="$(nvidia-smi 2>/dev/null | sed -n 's/.*CUDA Version: \([0-9.]*\).*/\1/p' | head -1)"

  if [[ -n "${CUDA_VER}" ]]; then
    pass "CUDA (driver)" "${CUDA_VER}"
  else
    warn "CUDA (driver)" "Could not detect CUDA version from nvidia-smi"
  fi

  REQ_VRAM="$(recommended_vram_gb "${VLLM_MODEL}")"
  if [[ "${TOTAL_VRAM_GB}" -ge 40 ]]; then
    pass "Total VRAM" "${TOTAL_VRAM_GB} GB — excellent for full stack"
  elif [[ "${TOTAL_VRAM_GB}" -ge 24 ]]; then
    pass "Total VRAM" "${TOTAL_VRAM_GB} GB — good for MVP (sequential jobs)"
  elif [[ "${TOTAL_VRAM_GB}" -ge "${REQ_VRAM}" ]]; then
    warn "Total VRAM" "${TOTAL_VRAM_GB} GB — OK for ${VLLM_MODEL}; run one GPU job at a time"
  else
    fail "Total VRAM" "${TOTAL_VRAM_GB} GB — need ~${REQ_VRAM} GB+ for ${VLLM_MODEL}"
  fi

  if [[ "${ENABLE_WAN}" == "true" ]] && [[ "${TOTAL_VRAM_GB}" -lt 24 ]]; then
    warn "Wan 2.2 FX" "ENABLE_WAN=true needs ~24 GB VRAM; consider ENABLE_WAN=false"
  fi
else
  fail "NVIDIA GPU" "Not detected — vLLM, Flux, MuseTalk require NVIDIA GPU"
  warn "GPU stack" "Compositor + API can run CPU-only; ML workers will not work"
fi

# ─── 5. System tools ───────────────────────────────────────────────────────────

section "System tools"

for cmd in git curl wget ffmpeg python3 node npm; do
  if command -v "${cmd}" >/dev/null 2>&1; then
    ver="$("${cmd}" --version 2>&1 | head -1 || true)"
    pass "${cmd}" "${ver:-installed}"
  else
    if [[ "${cmd}" == "wget" ]]; then
      warn "${cmd}" "missing (optional)"
    else
      fail "${cmd}" "missing — run: make install-system"
    fi
  fi
done

PY_VER="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || echo 0)"
if version_ge "3.10" "${PY_VER}"; then
  pass "Python" "${PY_VER} (≥3.10 required)"
else
  fail "Python" "${PY_VER} — need 3.10+"
fi

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if [[ "${NODE_MAJOR}" -ge 18 ]]; then
  pass "Node.js" "v$(node -v 2>/dev/null | tr -d v) (≥18 required)"
else
  fail "Node.js" "need v18+ for compositor"
fi

# ─── 6. Environment (.env) ─────────────────────────────────────────────────

section "Environment"

if [[ -f "${CORE_ROOT}/.env" ]]; then
  pass ".env file" "present"
else
  fail ".env file" "missing — run: make env"
fi

if [[ -n "${HF_TOKEN:-}" ]]; then
  pass "HF_TOKEN" "set (${#HF_TOKEN} chars)"
else
  warn "HF_TOKEN" "not set — required for make install-models (Flux + Qwen)"
fi

pass "VLLM_MODEL" "${VLLM_MODEL}"
pass "Paths" "vendor=${VENDOR_DIR##*/} models=${MODELS_DIR##*/}"

# ─── 7. Python environment ───────────────────────────────────────────────────

section "Python environment"

if [[ -f "${VENV_DIR}/bin/python" ]]; then
  VENV_PY="$("${VENV_DIR}/bin/python" --version 2>&1)"
  pass "venv" "${VENV_DIR} (${VENV_PY})"
else
  fail "venv" "missing — run: make install-python"
fi

if [[ -f "${VENV_DIR}/bin/python" ]]; then
  for pkg in fastapi uvicorn httpx pydantic huggingface_hub; do
    if "${VENV_DIR}/bin/python" -c "import ${pkg//-/_}" 2>/dev/null; then
      pass "pip:${pkg}" "installed"
    else
      fail "pip:${pkg}" "missing — run: make install-python"
    fi
  done

  if "${VENV_DIR}/bin/python" -c "import vllm" 2>/dev/null; then
    pass "pip:vllm" "installed"
  else
    warn "pip:vllm" "missing — run: make install-vllm"
  fi

  if "${VENV_DIR}/bin/pip" show lorecraft-core >/dev/null 2>&1; then
    pass "pip:lorecraft-core" "editable install OK"
  else
    warn "pip:lorecraft-core" "missing — run: make editable"
  fi
fi

# ─── 8. Vendor stack ─────────────────────────────────────────────────────────

section "Vendor repositories"

for name in ComfyUI CosyVoice MuseTalk; do
  if [[ -d "${VENDOR_DIR}/${name}/.git" ]] || [[ -d "${VENDOR_DIR}/${name}" ]]; then
    pass "${name}" "${VENDOR_DIR}/${name}"
  else
    warn "${name}" "not installed"
  fi
done

if [[ -d "${VENDOR_DIR}/ComfyUI/custom_nodes/ComfyUI-Manager" ]]; then
  pass "ComfyUI nodes" "Manager installed"
else
  warn "ComfyUI nodes" "run: make install-comfyui-nodes"
fi

# ─── 9. Models & assets ────────────────────────────────────────────────────────

section "Models & assets"

if dir_has_files "${HF_HOME}"; then
  pass "HF weights cache" "files present in ${HF_HOME}"
else
  warn "HF weights cache" "empty — run: make install-models"
fi

if dir_has_files "${MODELS_DIR}/checkpoints" || dir_has_files "${MODELS_DIR}/checkpoints/flux1-dev"; then
  pass "Flux checkpoint" "found under models/checkpoints"
else
  warn "Flux checkpoint" "missing — needs HF_TOKEN + make install-models"
fi

if [[ -f "${MODELS_DIR}/loras/pony_v6.safetensors" ]]; then
  pass "Pony LoRA" "models/loras/pony_v6.safetensors"
else
  warn "Pony LoRA" "missing — run: make install-loras"
fi

if dir_has_files "${MODELS_DIR}/cosyvoice"; then
  pass "CosyVoice weights" "found"
else
  warn "CosyVoice weights" "missing in ${MODELS_DIR}/cosyvoice"
fi

if dir_has_files "${MODELS_DIR}/musetalk"; then
  pass "MuseTalk weights" "found"
else
  warn "MuseTalk weights" "missing in ${MODELS_DIR}/musetalk"
fi

if [[ "${ENABLE_WAN}" == "true" ]]; then
  if dir_has_files "${MODELS_DIR}/wan"; then
    pass "Wan FX weights" "found"
  else
    warn "Wan FX weights" "ENABLE_WAN=true but models/wan is empty"
  fi
fi

# ─── 10. Compositor ──────────────────────────────────────────────────────────

section "Compositor"

if [[ -f "${CORE_ROOT}/compositor/package.json" ]]; then
  pass "compositor/package.json" "present"
else
  fail "compositor" "package.json missing"
fi

if [[ -d "${CORE_ROOT}/compositor/node_modules" ]]; then
  pass "compositor deps" "node_modules installed"
else
  warn "compositor deps" "run: make install-compositor"
fi

# ─── 11. Port availability ───────────────────────────────────────────────────

section "Service ports (conflicts)"

for entry in "vLLM:${VLLM_PORT:-8000}" "ComfyUI:${COMFYUI_PORT:-8188}" "CosyVoice:${COSYVOICE_PORT:-9001}" "Core API:${CORE_API_PORT:-8080}"; do
  name="${entry%%:*}"
  port="${entry##*:}"
  if port_in_use "${port}"; then
    warn "Port ${port}" "${name} — already in use (service may be running)"
  else
    pass "Port ${port}" "${name} — available"
  fi
done

# ─── Verdict ─────────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════════════════════"
printf "  Results:  \033[32m%d pass\033[0m   \033[33m%d warn\033[0m   \033[31m%d fail\033[0m\n" "${PASS}" "${WARN}" "${FAIL}"
echo "════════════════════════════════════════════════════════"

if [[ "${FAIL}" -eq 0 && "${WARN}" -eq 0 ]]; then
  log "This machine is fully configured for LoreCraft Core."
  exit 0
elif [[ "${FAIL}" -eq 0 ]]; then
  log "Machine is usable. Address warnings above for full stack readiness."
  echo ""
  echo "Suggested next steps:"
  [[ -z "${HF_TOKEN:-}" ]] && echo "  • Set HF_TOKEN in .env"
  [[ ! -d "${VENDOR_DIR}/ComfyUI" ]] && echo "  • make install-all"
  ! dir_has_files "${HF_HOME}" && echo "  • make install-models"
  [[ ! -f "${MODELS_DIR}/loras/pony_v6.safetensors" ]] && echo "  • make install-loras"
  exit 0
elif [[ "${FAIL}" -le 2 ]] && have_gpu; then
  warn "Machine has gaps but may work after: make install-all && make install-models"
  exit 1
else
  err "Machine is not correctly configured for the LoreCraft GPU stack."
  echo ""
  echo "Fix failures first, then re-run: make check-system"
  exit 1
fi
