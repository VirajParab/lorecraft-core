#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

bash "${SCRIPT_DIR}/ensure-node.sh"

log "Installing compositor npm dependencies..."
cd "${CORE_ROOT}/compositor"
npm install

log "Compositor ready."
