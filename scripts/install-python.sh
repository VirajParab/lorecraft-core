#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

ensure_dirs

if [[ ! -d "${VENV_DIR}" ]]; then
  log "Creating Python venv at ${VENV_DIR}"
  python3 -m venv "${VENV_DIR}"
fi

activate_venv
pip_install -r "${CORE_ROOT}/requirements.txt"

log "Python environment ready."
python --version
pip list | grep -E '^(fastapi|uvicorn|httpx|pydantic|huggingface-hub)' || true
