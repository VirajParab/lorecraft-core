#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

activate_venv
ensure_dirs

HF_TOKEN="${HF_TOKEN:-}"
MODEL="${VLLM_MODEL:-Qwen/Qwen3-8B}"
FLUX_MODEL="${FLUX_MODEL:-black-forest-labs/FLUX.1-dev}"

if [[ -z "${HF_TOKEN}" ]]; then
  warn "HF_TOKEN not set. Some downloads (Flux) require a Hugging Face token."
  warn "Copy .env.example to .env and set HF_TOKEN=hf_..."
fi

export HF_HOME="${CORE_ROOT}/hf_cache"
mkdir -p "${HF_HOME}"

export MODEL="${VLLM_MODEL:-Qwen/Qwen3-8B}"
export FLUX_MODEL="${FLUX_MODEL:-black-forest-labs/FLUX.1-dev}"
export MODELS_DIR

log "Downloading LLM weights: ${MODEL}"
python - <<'PY'
import os
from huggingface_hub import snapshot_download

token = os.environ.get("HF_TOKEN") or None
model = os.environ["MODEL"]
cache = os.environ["HF_HOME"]
print(f"Downloading {model} ...")
path = snapshot_download(repo_id=model, cache_dir=cache, token=token)
print(f"Cached at: {path}")
PY

export HF_TOKEN
export FLUX_MODEL

if [[ -n "${HF_TOKEN}" ]]; then
  log "Checking Hugging Face access to ${FLUX_MODEL}..."
  python - <<'PY' || die "Flux access check failed — fix Hugging Face settings above, then re-run: make install-models"
import os
import sys
from huggingface_hub import HfApi
from huggingface_hub.errors import GatedRepoError, HfHubHTTPError

token = os.environ.get("HF_TOKEN")
model = os.environ["FLUX_MODEL"]
api = HfApi(token=token)

try:
    api.model_info(model)
    print(f"Access OK: {model}")
except GatedRepoError:
    print(f"\nGated model — accept the license first:\n  https://huggingface.co/{model}", file=sys.stderr)
    print("Use the same Hugging Face account that owns HF_TOKEN in .env", file=sys.stderr)
    sys.exit(1)
except HfHubHTTPError as e:
    if e.response is not None and e.response.status_code == 403:
        print("\n403 Forbidden — your HF token cannot read gated repos.", file=sys.stderr)
        print("Fix (pick one):", file=sys.stderr)
        print("  1. Accept license: https://huggingface.co/black-forest-labs/FLUX.1-dev", file=sys.stderr)
        print("  2. Fine-grained token: Settings → Tokens → edit token → enable", file=sys.stderr)
        print("     'Read access to contents of all public gated repos you can access'", file=sys.stderr)
        print("  3. Or create a classic Read token: https://huggingface.co/settings/tokens", file=sys.stderr)
        print("Then update HF_TOKEN in .env and re-run: make install-models", file=sys.stderr)
        sys.exit(1)
    raise
PY

  log "Downloading Flux checkpoint: ${FLUX_MODEL}"
  python - <<'PY'
import os
from huggingface_hub import snapshot_download

token = os.environ.get("HF_TOKEN")
model = os.environ["FLUX_MODEL"]
dest = os.path.join(os.environ["MODELS_DIR"], "checkpoints", "flux1-dev")
os.makedirs(dest, exist_ok=True)
print(f"Downloading {model} ...")
path = snapshot_download(repo_id=model, cache_dir=dest, token=token)
print(f"Flux cached at: {path}")
PY
else
  warn "Skipping Flux download (HF_TOKEN required). Place checkpoint manually in models/checkpoints/"
fi

log "Model download pass complete."
log "Pony LoRA: place pony_v6.safetensors in models/loras/ (see scripts/download-loras.sh)"
