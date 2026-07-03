#!/usr/bin/env bash
# Install Node.js 20 + npm if missing or older than 18 (compositor / Remotion).
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

need_node() {
  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    return 0
  fi
  [[ "$(node -p 'process.versions.node.split(".")[0]')" -lt 18 ]]
}

if ! need_node; then
  log "Node $(node --version), npm $(npm --version)"
  exit 0
fi

log "Node.js 18+ / npm not found — installing Node.js 20..."

if command -v apt-get >/dev/null 2>&1; then
  run_root_bash_script "https://deb.nodesource.com/setup_20.x"
  run_root apt-get install -y nodejs
elif command -v dnf >/dev/null 2>&1; then
  run_root dnf install -y nodejs npm || {
    warn "dnf nodejs unavailable — install Node 18+ manually: https://nodejs.org/"
    exit 1
  }
else
  die "Install Node.js 18+ manually: https://nodejs.org/"
fi

require_cmd node
require_cmd npm
log "Node $(node --version), npm $(npm --version)"
