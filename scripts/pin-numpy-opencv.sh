#!/usr/bin/env bash
# ComfyUI / MuseTalk opencv wheels are built against NumPy 1.x. vLLM and other
# deps may upgrade to NumPy 2.x — re-pin and rebuild opencv bindings.
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

activate_venv

log "Pinning NumPy 1.x + reinstalling OpenCV (ComfyUI / cv2 compatibility)..."

pip_install "numpy>=1.26,<2"
pip_install --force-reinstall "opencv-python-headless>=4.8.0"

python - <<'PY'
import numpy as np
import cv2
print(f"numpy {np.__version__}, opencv {cv2.__version__}")
PY

log "NumPy/OpenCV stack OK."
