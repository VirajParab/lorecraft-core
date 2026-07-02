"""Configuration loaded from environment / .env."""

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Paths
    core_root: Path = Path(__file__).resolve().parents[2]
    vendor_dir: Path = Path("vendor")
    models_dir: Path = Path("models")
    data_dir: Path = Path("data")

    # Services
    vllm_port: int = 8000
    comfyui_port: int = 8188
    cosyvoice_port: int = 9001
    core_api_port: int = 8080

    vllm_model: str = "Qwen/Qwen3-8B"
    vllm_base_url: str = "http://127.0.0.1:8000/v1"

    comfyui_host: str = "127.0.0.1"
    comfyui_port_num: int = 8188

    compositor_fps: int = 30
    compositor_width: int = 1920
    compositor_height: int = 1080

    hf_token: str | None = None

    @property
    def vendor_path(self) -> Path:
        p = self.vendor_dir
        return p if p.is_absolute() else self.core_root / p

    @property
    def models_path(self) -> Path:
        p = self.models_dir
        return p if p.is_absolute() else self.core_root / p

    @property
    def data_path(self) -> Path:
        p = self.data_dir
        return p if p.is_absolute() else self.core_root / p

    @property
    def comfyui_url(self) -> str:
        return f"http://{self.comfyui_host}:{self.comfyui_port_num}"


@lru_cache
def get_settings() -> Settings:
    return Settings()
