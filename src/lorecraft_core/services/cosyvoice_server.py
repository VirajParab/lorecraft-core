"""Minimal CosyVoice HTTP placeholder — replace with full inference when models are downloaded."""

from __future__ import annotations

import argparse
from pathlib import Path

import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="LoreCraft CosyVoice", version="0.1.0")

MODEL_DIR: Path | None = None


class TTSRequest(BaseModel):
    text: str
    voice_id: str = "default"


class TTSResponse(BaseModel):
    status: str
    message: str
    output_path: str | None = None


@app.get("/health")
def health() -> dict[str, str]:
    ready = MODEL_DIR is not None and MODEL_DIR.exists() and any(MODEL_DIR.iterdir())
    return {"status": "ready" if ready else "models_missing", "model_dir": str(MODEL_DIR)}


@app.post("/v1/tts", response_model=TTSResponse)
def synthesize(req: TTSRequest) -> TTSResponse:
    if MODEL_DIR is None or not MODEL_DIR.exists() or not any(MODEL_DIR.iterdir()):
        raise HTTPException(
            status_code=503,
            detail="CosyVoice models not found. Download weights to COSYVOICE_MODEL_DIR.",
        )
    # TODO: wire FunAudioLLM/CosyVoice inference
    return TTSResponse(
        status="not_implemented",
        message="CosyVoice server is running; wire inference in lorecraft_core.services.cosyvoice_server",
        output_path=None,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=9001)
    parser.add_argument("--model-dir", type=Path, required=True)
    args = parser.parse_args()

    global MODEL_DIR
    MODEL_DIR = args.model_dir

    uvicorn.run(app, host=args.host, port=args.port)


if __name__ == "__main__":
    main()
