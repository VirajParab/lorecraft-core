# LoreCraft Core — Makefile
# Run `make` or `make help` to see all commands.

SHELL := /bin/bash
.DEFAULT_GOAL := help

CORE_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SCRIPTS := $(CORE_ROOT)/scripts
VENV := $(CORE_ROOT)/.venv
PYTHON := $(VENV)/bin/python
PIP := $(VENV)/bin/pip

# Note: .env is loaded by scripts/common.sh (not Makefile — slashes in model IDs break make)

.PHONY: help
.PHONY: install install-all install-system install-python install-vllm
.PHONY: install-comfyui install-comfyui-nodes install-models install-loras
.PHONY: install-cosyvoice install-musetalk install-fish-speech install-wan
.PHONY: repair-gpu-stack fix-nccl
.PHONY: install-compositor install-dev editable
.PHONY: serve-vllm serve-comfyui serve-cosyvoice serve-api serve-all
.PHONY: health status check-system check-box test lint clean env

help: ## Show this help
	@echo "LoreCraft Core — open-source anime engine stack"
	@echo ""
	@grep -E '^[a-zA-Z0-9_.-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Quick start:"
	@echo "  cp .env.example .env   # set HF_TOKEN for model downloads"
	@echo "  make install-all"
	@echo "  make install-models    # downloads Qwen + Flux (needs HF_TOKEN)"
	@echo "  make serve-comfyui     # terminal 1"
	@echo "  make serve-vllm        # terminal 2 (GPU)"

env: ## Copy .env.example to .env if missing
	@if [ ! -f .env ]; then cp .env.example .env && echo "Created .env — edit HF_TOKEN"; else echo ".env already exists"; fi

# ─── Install targets ─────────────────────────────────────────────────────────

install-system: ## apt/dnf: git, ffmpeg, python3, nodejs
	bash $(SCRIPTS)/install-system-deps.sh

install-python: env ## Create venv + pip install core requirements
	bash $(SCRIPTS)/install-python.sh

install-vllm: install-python ## Install vLLM for Qwen3 LLM serving
	bash $(SCRIPTS)/install-vllm.sh

install-comfyui: install-python ## Clone ComfyUI + link model dirs
	bash $(SCRIPTS)/install-comfyui.sh

install-comfyui-nodes: install-comfyui ## IPAdapter, Manager, VideoHelperSuite, etc.
	bash $(SCRIPTS)/install-comfyui-nodes.sh

install-models: install-python ## Download Qwen + Flux via Hugging Face
	bash $(SCRIPTS)/install-models.sh

install-loras: ## Download Pony LoRA (set PONY_LORA_URL in .env)
	bash $(SCRIPTS)/download-loras.sh

install-cosyvoice: install-vllm ## Clone FunAudioLLM/CosyVoice + deps (uses vLLM torch stack)
	bash $(SCRIPTS)/install-cosyvoice.sh

install-musetalk: install-vllm ## Clone TMElyralab/MuseTalk + deps (uses vLLM torch stack)
	bash $(SCRIPTS)/install-musetalk.sh

repair-gpu-stack: install-python ## Reinstall vLLM + torch after a conflicting pip install
	bash $(SCRIPTS)/repair-gpu-stack.sh

fix-nccl: install-python ## Fix ncclComm* undefined symbol (RunPod NCCL mismatch)
	bash $(SCRIPTS)/fix-nccl.sh

install-fish-speech: install-python ## Optional TTS fallback
	bash $(SCRIPTS)/install-fish-speech.sh

install-wan: install-comfyui ## Prepare Wan 2.2 FX video (optional, heavy)
	bash $(SCRIPTS)/install-wan.sh

install-compositor: ## npm install Remotion compositor
	cd compositor && npm install

install-dev: install-python ## Dev tools: pytest, ruff, mypy
	$(PIP) install -r requirements-dev.txt

editable: install-python ## Install lorecraft_core package in editable mode
	$(PIP) install -e .

install: install-python install-compositor editable ## Minimal install (no GPU vendors)

install-all: install-system install-python install-vllm install-comfyui install-comfyui-nodes install-cosyvoice install-musetalk install-compositor editable ## Full OSS stack install
	@echo ""
	@echo "Next steps:"
	@echo "  1. Set HF_TOKEN in .env"
	@echo "  2. make install-models"
	@echo "  3. make install-loras"
	@echo "  4. make health"

# ─── Serve targets ───────────────────────────────────────────────────────────

serve-vllm: ## Start vLLM (Qwen3) on port $(VLLM_PORT)
	bash $(SCRIPTS)/serve-vllm.sh

serve-comfyui: ## Start ComfyUI on port $(COMFYUI_PORT)
	bash $(SCRIPTS)/serve-comfyui.sh

serve-cosyvoice: ## Start CosyVoice HTTP wrapper on port $(COSYVOICE_PORT)
	bash $(SCRIPTS)/serve-cosyvoice.sh

serve-api: editable ## Start LoreCraft Core API on port $(CORE_API_PORT)
	$(VENV)/bin/uvicorn lorecraft_core.api:app --host 0.0.0.0 --port $(or $(CORE_API_PORT),8080) --reload

serve-all: ## Print commands to run each service in separate terminals
	@echo "Run in separate terminals:"
	@echo "  make serve-comfyui"
	@echo "  make serve-vllm"
	@echo "  make serve-cosyvoice"
	@echo "  make serve-api"

# ─── Ops ─────────────────────────────────────────────────────────────────────

health: ## Check installed components and running services
	bash $(SCRIPTS)/healthcheck.sh

check-system: ## Validate hardware, deps, models, and stack readiness
	bash $(SCRIPTS)/check-system.sh

check-box: check-system ## Alias: check this machine's configuration

status: health ## Alias for health (running services only)

test: editable install-dev ## Run pytest
	$(VENV)/bin/pytest -q

lint: editable install-dev ## Ruff + mypy
	$(VENV)/bin/ruff check src tests
	$(VENV)/bin/mypy src

clean: ## Remove venv caches and compositor node_modules
	rm -rf .pytest_cache .mypy_cache .ruff_cache
	rm -rf compositor/node_modules compositor/dist
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true

clean-vendor: ## Remove cloned vendor repos (re-run make install-comfyui etc.)
	rm -rf vendor/

clean-all: clean clean-vendor ## Remove vendor + caches (keeps models/)
