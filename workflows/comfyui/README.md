# ComfyUI Workflows

Export workflow JSON files here from ComfyUI for:

- `flux_character_sheet.json` — multi-view character reference
- `flux_sprite.json` — pose + expression sprite with IP-Adapter
- `flux_background.json` — 1920×1080 location
- `musetalk_lipsync.json` — face + audio → lip video
- `wan_fx_overlay.json` — 3–5s FX clip (optional)

## Usage

1. `make serve-comfyui`
2. Build workflows in the UI at http://127.0.0.1:8188
3. Save API format JSON to this directory
4. Wire to `lorecraft_core` job workers (coming in Phase B)

See [../../docs/pipeline.md](../../docs/pipeline.md) for pipeline context.
