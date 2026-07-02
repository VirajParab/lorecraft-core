#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

activate_venv
ensure_dirs

FISH_DIR="${VENDOR_DIR}/fish-speech"
clone_repo "https://github.com/fishaudio/fish-speech.git" "${FISH_DIR}"

log "Installing Fish Speech (optional TTS fallback)..."
if [[ -f "${FISH_DIR}/requirements.txt" ]]; then
  pip_install -r "${FISH_DIR}/requirements.txt"
fi

log "Fish Speech installed at ${FISH_DIR}"
