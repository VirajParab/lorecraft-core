# LoreCraft Core

Anime production engine for [LoreCraft](https://lorecraft.site).

**License:** [PolyForm Noncommercial 1.0.0](../LICENSE) — noncommercial use only.
Commercial use is reserved to Viraj Parab unless you obtain a separate license.

Implements the studio-style stack documented in `../docs/`:

- **Director LLM** — Qwen3 via vLLM
- **Image generation** — Flux Dev + Pony LoRA via ComfyUI
- **TTS** — CosyVoice 2
- **Lip sync** — MuseTalk
- **FX video** — Wan 2.2 (optional, ComfyUI)
- **Compositor** — Remotion (2D sprite + camera)
- **Assembly** — FFmpeg

## Requirements

- **OS:** Linux (Ubuntu 22.04+ recommended)
- **GPU:** NVIDIA with 24GB+ VRAM for comfortable dev (A100 40GB ideal). Qwen3-8B works on 16GB.
- **Disk:** ~100GB+ for models (Flux + Qwen; Wan adds more)
- **Tools:** git, curl, ffmpeg, Python 3.10+, Node 18+

## Quick start

```bash
cd core
cp .env.example .env
# Edit .env — set HF_TOKEN from https://huggingface.co/settings/tokens
# Accept FLUX.1-dev license on Hugging Face

make install-all      # system deps + venv + ComfyUI + CosyVoice + MuseTalk + compositor
make install-models   # download Qwen + Flux weights
make install-loras    # Pony LoRA (manual or PONY_LORA_URL)

make health           # verify installation
```

## Run services

Each service runs in its own terminal (or use systemd/docker later):

```bash
make serve-comfyui    # http://127.0.0.1:8188 — Flux, MuseTalk, Wan workflows
make serve-vllm       # http://127.0.0.1:8000 — Qwen3 Director LLM
make serve-cosyvoice  # http://127.0.0.1:9001 — TTS
make serve-api        # http://127.0.0.1:8080 — LoreCraft orchestration API (stub)
```

```bash
make serve-all        # print all serve commands
```

## Makefile reference

| Command | Description |
|---------|-------------|
| `make help` | Show all commands |
| `make env` | Create `.env` from example |
| `make install-all` | Full stack install |
| `make install-system` | apt/dnf system packages only |
| `make install-python` | venv + pip requirements |
| `make install-vllm` | vLLM for Qwen3 |
| `make install-comfyui` | Clone ComfyUI |
| `make install-comfyui-nodes` | IPAdapter, Manager, VideoHelper |
| `make install-models` | HF download Qwen + Flux |
| `make install-loras` | Pony LoRA |
| `make install-cosyvoice` | CosyVoice TTS |
| `make install-musetalk` | MuseTalk lip-sync |
| `make install-fish-speech` | Optional TTS fallback |
| `make install-wan` | Wan 2.2 FX setup guide |
| `make install-compositor` | Remotion npm deps |
| `make install-dev` | pytest, ruff, mypy |
| `make editable` | `pip install -e .` |
| `make check-system` | Validate hardware, deps, models, and readiness |
| `make check-box` | Alias for check-system |
| `make health` | Health check (running services) |
| `make test` | Run tests |
| `make lint` | Ruff + mypy |
| `make clean` | Clear caches |

## Directory layout

```
core/
├── Makefile
├── .env.example
├── requirements.txt
├── scripts/           # install + serve scripts
├── src/lorecraft_core/  # Python API, config, health
├── compositor/        # Remotion shot renderer
├── vendor/            # cloned repos (ComfyUI, CosyVoice, MuseTalk) — gitignored
├── models/            # checkpoints, loras, voice weights — gitignored
├── workflows/comfyui/   # ComfyUI workflow JSON exports
└── data/              # runtime output — gitignored
```

## Model notes

| Model | Default | VRAM | Install |
|-------|---------|------|---------|
| Qwen3-8B | dev default | ~16GB | `make install-models` |
| Qwen3-32B-AWQ | production | ~20GB | set `VLLM_MODEL` in `.env` |
| FLUX.1-dev | image gen | ~12GB | `make install-models` + HF_TOKEN |
| Pony V6 LoRA | anime style | — | `make install-loras` |
| CosyVoice | TTS | ~4GB | weights → `models/cosyvoice/` |
| MuseTalk | lip-sync | ~8GB | weights → `models/musetalk/` |
| Wan 2.2 | FX only | ~24GB | `make install-wan` |

## Compositor

```bash
make install-compositor
cd compositor && npm run studio    # Remotion preview UI
cd compositor && npm run render:shot
```

## Development

```bash
make install-dev
make editable
make test
make lint
```

## Related docs

- [../docs/development.md](../docs/development.md) — technical thesis
- [../docs/open-source-stack.md](../docs/open-source-stack.md) — model details
- [../docs/mvp.md](../docs/mvp.md) — build phases
- [../docs/schemas.md](../docs/schemas.md) — data contracts

## License

LoreCraft Core application code: proprietary (LoreCraft).  
Third-party models and tools have their own licenses — see `docs/open-source-stack.md`.
