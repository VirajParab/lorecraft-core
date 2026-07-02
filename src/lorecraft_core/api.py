"""LoreCraft Core API — orchestration entrypoint (stub)."""

from fastapi import FastAPI

from lorecraft_core import __version__
from lorecraft_core.health import run_health

app = FastAPI(title="LoreCraft Core", version=__version__)


@app.get("/health")
async def health():
    checks = await run_health()
    ok = checks["ffmpeg"] and checks["venv"]
    return {"status": "ok" if ok else "degraded", "checks": checks, "version": __version__}


@app.get("/")
def root():
    return {
        "name": "LoreCraft Core",
        "version": __version__,
        "docs": "../docs/README.md",
    }
