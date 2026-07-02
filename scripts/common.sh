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
export VENDOR_DIR="${VENDOR_DIR:-${CORE_ROOT}/vendor}"
export MODELS_DIR="${MODELS_DIR:-${CORE_ROOT}/models}"
export DATA_DIR="${DATA_DIR:-${CORE_ROOT}/data}"
export VENV_DIR="${VENV_DIR:-${CORE_ROOT}/.venv}"

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
}

ensure_dirs() {
  mkdir -p "${VENDOR_DIR}" "${MODELS_DIR}" "${DATA_DIR}" "${DATA_DIR}/cache" "${DATA_DIR}/output" "${DATA_DIR}/audio"
  mkdir -p "${MODELS_DIR}/loras" "${MODELS_DIR}/checkpoints" "${MODELS_DIR}/vae" "${MODELS_DIR}/clip"
  mkdir -p "${MODELS_DIR}/cosyvoice" "${MODELS_DIR}/musetalk" "${MODELS_DIR}/wan"
}

have_gpu() {
  command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1
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
  if [[ -n "${branch}" ]]; then
    git clone --depth 1 --branch "${branch}" "${url}" "${dest}"
  else
    git clone --depth 1 "${url}" "${dest}"
  fi
}

pip_install() {
  activate_venv
  python -m pip install --upgrade pip wheel setuptools
  python -m pip install "$@"
}
