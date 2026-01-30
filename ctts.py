#!/usr/bin/env python3
# ctts.py — Voice-cloned Text-to-Speech using Coqui XTTS-v2
# Caches final (post-processed) wavs in /tmp based on hash(text + speaker clip contents + filter version).

"""
ctts.py — Voice-cloned Text-to-Speech using Coqui XTTS-v2

Generates new speech in the voice of any speaker from a short reference clip.

────────────────────────────────────────────────────────
DEPENDENCIES
────────────────────────────────────────────────────────

System:
  - sox (for final audio filtering)
    Debian/Ubuntu: sudo apt install sox
    Fedora:        sudo dnf install sox
    Arch:          sudo pacman -S sox

Python:
  - torch
  - torchaudio
  - coqui-tts[codec]
  - soundfile
  - numpy

────────────────────────────────────────────────────────
INSTALLATION
────────────────────────────────────────────────────────

Do this from your Whisper Radio project root.

GPU (NVIDIA, recommended):

  python3 -m venv tts
  source tts/bin/activate
  pip install -U pip wheel setuptools

  # CUDA PyTorch (try cu124, fallback cu121)
  pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu124
  # or:
  # pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu121

  pip install "coqui-tts[codec]" soundfile numpy

CPU-only:

  python3 -m venv tts
  source tts/bin/activate
  pip install -U pip wheel setuptools

  pip install torch --index-url https://download.pytorch.org/whl/cpu
  pip install torchaudio --index-url https://download.pytorch.org/whl/cpu

  pip install "coqui-tts[codec]" soundfile numpy

────────────────────────────────────────────────────────
VERIFY GPU
────────────────────────────────────────────────────────

  python -c "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_name(0) if torch.cuda.is_available() else None)"

────────────────────────────────────────────────────────
REFERENCE VOICE
────────────────────────────────────────────────────────

speaker.wav:
  mono, 16-bit, 22050 or 44100 Hz
  no music, no noise, minimal reverb, steady volume

────────────────────────────────────────────────────────
FIRST RUN
────────────────────────────────────────────────────────

Run this script once to accept the Coqui license prompt.

────────────────────────────────────────────────────────
USAGE
────────────────────────────────────────────────────────

  ./ctts.py "Your text here" out.wav speaker.wav
"""

import sys
import os
import hashlib
import shutil
import subprocess

import torch
from TTS.api import TTS


FILTER_VERSION = "sox:v1:highpass120:reverb20:compand0.3,1_6:-70,-60,-20:gain-3"


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_file_bytes(path: str) -> bytes:
    with open(path, "rb") as f:
        return f.read()


def ensure_parent_dir(path: str) -> None:
    parent = os.path.dirname(os.path.abspath(path))
    if parent:
        os.makedirs(parent, exist_ok=True)


def sox_filter(in_wav: str, out_wav: str) -> None:
    cmd = [
        "sox", in_wav, out_wav,
        "highpass", "120",
        "reverb", "20",
        "compand", "0.3,1", "6:-70,-60,-20",
        "gain", "-3",
    ]
    subprocess.check_call(cmd)


def synth_to_file(text: str, speaker_wav: str, out_wav: str, gpu: bool) -> None:
    """
    Synthesize to out_wav. If gpu=True and CUDA is available, attempt GPU.
    """
    tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2", gpu=gpu)
    tts.tts_to_file(
        text=text,
        speaker_wav=speaker_wav,
        language="en",
        file_path=out_wav,
    )


def main() -> int:
    if len(sys.argv) != 4:
        print('Usage: ctts.py "text" out.wav speaker.wav')
        return 1

    text = sys.argv[1]
    out_path = sys.argv[2]
    speaker_wav = sys.argv[3]

    # Hash includes:
    #   - text bytes
    #   - speaker wav file contents (so changing the speaker clip changes the cache key)
    #   - filter version string (so changing SoX chain invalidates cache)
    speaker_bytes = read_file_bytes(speaker_wav)
    key_material = (
        text.encode("utf-8") + b"\n---\n" +
        speaker_bytes + b"\n---\n" +
        FILTER_VERSION.encode("utf-8")
    )
    key = sha256_bytes(key_material)[:16]

    cache_final = f"/tmp/ctts_{key}.wav"
    cache_raw = f"/tmp/ctts_{key}_raw.wav"

    ensure_parent_dir(out_path)

    # If final cached output already exists, just copy it and exit.
    if os.path.exists(cache_final):
        shutil.copyfile(cache_final, out_path)
        print(f"Cache hit: {cache_final} -> {out_path}")
        return 0

    use_gpu = bool(torch.cuda.is_available())
    print("GPU available:", use_gpu)

    # Generate raw TTS (GPU first, fall back to CPU on CUDA OOM)
    print("Synthesizing...")
    try:
        synth_to_file(text=text, speaker_wav=speaker_wav, out_wav=cache_raw, gpu=use_gpu)
    except torch.OutOfMemoryError:
        # Most common on small VRAM cards (e.g. 2GB). Fall back to CPU.
        print("CUDA OOM during synthesis; falling back to CPU.")
        try:
            torch.cuda.empty_cache()
        except Exception:
            pass
        synth_to_file(text=text, speaker_wav=speaker_wav, out_wav=cache_raw, gpu=False)

    # Post-process into cached final
    print("Filtering (SoX)...")
    sox_filter(cache_raw, cache_final)

    # Copy cached final to requested output path
    shutil.copyfile(cache_final, out_path)
    print(f"Wrote {out_path} (cached at {cache_final})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

