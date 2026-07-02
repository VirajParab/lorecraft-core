#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

log "Installing system dependencies (requires sudo on Debian/Ubuntu)..."

PKGS=(
  git curl wget ca-certificates
  build-essential pkg-config
  ffmpeg
  python3 python3-venv python3-dev
  libsndfile1 libgl1 libglib2.0-0
)

if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y "${PKGS[@]}"
elif command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y git curl wget ffmpeg python3 python3-devel gcc gcc-c++ pkgconfig libsndfile
else
  warn "Unknown package manager. Install manually: git curl wget ffmpeg python3 python3-venv build-essential"
fi

# Node.js 20 LTS via NodeSource (if node missing or too old)
if ! command -v node >/dev/null 2>&1 || [[ "$(node -p 'process.versions.node.split(".")[0]')" -lt 18 ]]; then
  log "Installing Node.js 20..."
  if command -v apt-get >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
  else
    warn "Install Node.js 18+ manually: https://nodejs.org/"
  fi
fi

require_cmd git
require_cmd curl
require_cmd ffmpeg
require_cmd python3
require_cmd node
require_cmd npm

log "System dependencies OK."
node --version
python3 --version
ffmpeg -version | head -n 1
