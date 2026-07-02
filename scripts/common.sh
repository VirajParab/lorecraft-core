#!/usr/bin/env bash
# Shared helpers for LoreCraft Core install scripts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${CORE_ROOT}/.env" ]]; then
  # shellcheck disable=SC1091
  set -a
  source "${CORE_ROOT}/.env"
  set +a
fi

export CORE_ROOT
export VENDOR_DIR="${VENDOR_DIR:-vendor}"
export MODELS_DIR="${MODELS_DIR:-models}"
export DATA_DIR="${DATA_DIR:-data}"
export VENV_DIR="${VENV_DIR:-.venv}"

# Resolve paths from CORE_ROOT so installs work regardless of shell cwd (.env uses relative paths).
abs_path_under_core() {
  local p="$1"
  if [[ "${p}" == /* ]]; then
    printf '%s\n' "${p}"
  else
    printf '%s\n' "${CORE_ROOT}/${p}"
  fi
}

export VENDOR_DIR="$(abs_path_under_core "${VENDOR_DIR}")"
export MODELS_DIR="$(abs_path_under_core "${MODELS_DIR}")"
export DATA_DIR="$(abs_path_under_core "${DATA_DIR}")"
export VENV_DIR="$(abs_path_under_core "${VENV_DIR}")"

log() {
  printf '\033[1;34m[lorecraft]\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33m[lorecraft]\033[0m %s\n' "$*" >&2
}

err() {
  printf '\033[1;31m[lorecraft]\033[0m %s\n' "$*" >&2
}

die() {
  err "$@"
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

activate_venv() {
  [[ -f "${VENV_DIR}/bin/activate" ]] || die "Python venv not found. Run: make install-python"
  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
  setup_gpu_library_path
}

venv_site_packages() {
  python -c "import site; print(site.getsitepackages()[0])"
}

# Prefer venv CUDA/NCCL libs over older system libs (RunPod templates often set LD_LIBRARY_PATH).
setup_gpu_library_path() {
  local site torch_lib nccl_lib extra="" nvidia_lib
  site="$(venv_site_packages 2>/dev/null)" || return 0

  torch_lib="${site}/torch/lib"
  nccl_lib="${site}/nvidia/nccl/lib"

  [[ -d "${torch_lib}" ]] && extra="${torch_lib}"
  [[ -d "${nccl_lib}" ]] && extra="${extra}${extra:+:}${nccl_lib}"

  for nvidia_lib in "${site}"/nvidia/*/lib; do
    [[ -d "${nvidia_lib}" ]] || continue
    case ":${extra}:" in
      *:"${nvidia_lib}":*) continue ;;
    esac
    extra="${extra}${extra:+:}${nvidia_lib}"
  done

  if [[ -n "${extra}" ]]; then
    export LD_LIBRARY_PATH="${extra}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
  fi
}

ensure_nccl_matches_torch() {
  activate_venv
  log "Ensuring NVIDIA NCCL matches PyTorch (avoids ncclComm* symbol errors)..."
  pip_install --upgrade nvidia-nccl-cu12 || warn "Could not upgrade nvidia-nccl-cu12"
  setup_gpu_library_path
}

ensure_dirs() {
  mkdir -p "${VENDOR_DIR}" "${MODELS_DIR}" "${DATA_DIR}" "${DATA_DIR}/cache" "${DATA_DIR}/output" "${DATA_DIR}/audio"
  mkdir -p "${MODELS_DIR}/loras" "${MODELS_DIR}/checkpoints" "${MODELS_DIR}/vae" "${MODELS_DIR}/clip"
  mkdir -p "${MODELS_DIR}/cosyvoice" "${MODELS_DIR}/musetalk" "${MODELS_DIR}/wan"
}

have_gpu() {
  command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1
}

# Print why torch/vllm are missing or fail to import (used after pip installs).
verify_gpu_stack() {
  activate_venv
  log "venv: ${VENV_DIR}"
  log "python: $(command -v python) ($(python --version 2>&1))"

  if ! pip show torch >/dev/null 2>&1; then
    err "Package 'torch' is not installed in this venv."
    pip list 2>/dev/null | grep -iE 'torch|vllm' || true
    return 1
  fi

  if ! python -c "import torch; print('torch', torch.__version__)"; then
    err "torch is installed but failed to import (see error above)."
    return 1
  fi

  if ! pip show vllm >/dev/null 2>&1; then
    err "Package 'vllm' is not installed in this venv."
    return 1
  fi

  if ! python -c "import vllm; print('vllm', vllm.__version__)"; then
    err "vllm is installed but failed to import (see error above)."
    return 1
  fi

  return 0
}

# CosyVoice/MuseTalk share the same venv as vLLM — never downgrade torch in their install scripts.
require_vllm_torch_stack() {
  activate_venv
  if verify_gpu_stack >/dev/null 2>&1; then
    local torch_ver
    torch_ver="$(python -c "import torch; print(torch.__version__)")"
    log "Using existing PyTorch ${torch_ver} (shared vLLM GPU stack)"
    return 0
  fi

  warn "GPU stack incomplete — running install-vllm.sh..."
  bash "${SCRIPT_DIR}/install-vllm.sh"

  verify_gpu_stack || die "GPU stack still broken after install-vllm. See errors above."
  local torch_ver
  torch_ver="$(python -c "import torch; print(torch.__version__)")"
  log "Using existing PyTorch ${torch_ver} (shared vLLM GPU stack)"
}

is_root() {
  [[ "$(id -u)" -eq 0 ]]
}

# Run a command as root — directly when already root (e.g. RunPod), else via sudo.
run_root() {
  if is_root; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    die "Root privileges required: $* (run as root or install sudo)"
  fi
}

# Pipe a curl setup script into bash with correct privileges (NodeSource, etc.).
run_root_bash_script() {
  local url="$1"
  if is_root; then
    curl -fsSL "$url" | bash -
  elif command -v sudo >/dev/null 2>&1; then
    curl -fsSL "$url" | sudo -E bash -
  else
    die "Root privileges required to run setup script: $url"
  fi
}

clone_repo() {
  local url="$1"
  local dest="$2"
  local branch="${3:-}"

  if [[ -d "${dest}/.git" ]]; then
    log "Already cloned: ${dest}"
    return 0
  fi

  mkdir -p "$(dirname "${dest}")"
  # Fail fast on private/missing repos — never block install on an interactive login prompt.
  if [[ -n "${branch}" ]]; then
    GIT_TERMINAL_PROMPT=0 git clone --depth 1 --branch "${branch}" "${url}" "${dest}"
  else
    GIT_TERMINAL_PROMPT=0 git clone --depth 1 "${url}" "${dest}"
  fi
}

pip_install() {
  activate_venv
  # setuptools 82+ breaks building openai-whisper and other legacy sdists (pkg_resources).
  python -m pip install --upgrade pip wheel "setuptools>=68,<82"
  python -m pip install "$@"
}
