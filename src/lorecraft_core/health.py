"""Health checks for installed stack components."""

from __future__ import annotations

import shutil
from pathlib import Path

import httpx

from lorecraft_core.config import get_settings


def check_ffmpeg() -> bool:
    return shutil.which("ffmpeg") is not None


def check_venv() -> bool:
    s = get_settings()
    return (s.core_root / ".venv" / "bin" / "python").exists()


def check_vendor(name: str) -> bool:
    s = get_settings()
    return (s.vendor_path / name).is_dir()


async def check_http(url: str, timeout: float = 2.0) -> bool:
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            r = await client.get(url)
            return r.status_code < 500
    except Exception:
        return False


async def run_health() -> dict[str, bool]:
    s = get_settings()
    vllm_ok = await check_http(f"{s.vllm_base_url.rstrip('/v1')}/health") or await check_http(
        f"{s.vllm_base_url}/models"
    )
    comfy_ok = await check_http(f"{s.comfyui_url}/")

    return {
        "ffmpeg": check_ffmpeg(),
        "venv": check_venv(),
        "comfyui_vendor": check_vendor("ComfyUI"),
        "cosyvoice_vendor": check_vendor("CosyVoice"),
        "musetalk_vendor": check_vendor("MuseTalk"),
        "vllm_service": vllm_ok,
        "comfyui_service": comfy_ok,
    }
