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
import re
import hashlib
import shutil
import subprocess
import tempfile

import numpy as np
import soundfile as sf
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


def split_text_for_xtts(text: str, max_chars: int = 250) -> list:
    """Sentence-aware greedy packer.

    XTTS-v2 caps inference at 400 BPE tokens; long inputs assert. We split
    on sentence boundaries, fall back to comma/semicolon/colon then
    whitespace for sentences that are themselves too long, and greedy-pack
    the resulting atomic units into chunks of <= max_chars characters.
    """
    normalized = re.sub(r"\s+", " ", text).strip()
    if not normalized:
        return [text]

    sentences = re.split(r"(?<=[.!?])\s+", normalized)

    atoms = []
    for s in sentences:
        if len(s) <= max_chars:
            atoms.append(s)
            continue
        for piece in re.split(r"(?<=[,;:])\s+", s):
            if len(piece) <= max_chars:
                atoms.append(piece)
                continue
            buf = ""
            for w in piece.split():
                candidate = (buf + " " + w) if buf else w
                if len(candidate) <= max_chars:
                    buf = candidate
                else:
                    if buf:
                        atoms.append(buf)
                    buf = w
            if buf:
                atoms.append(buf)

    chunks = []
    buf = ""
    for a in atoms:
        candidate = (buf + " " + a) if buf else a
        if len(candidate) <= max_chars:
            buf = candidate
        else:
            if buf:
                chunks.append(buf)
            buf = a
    if buf:
        chunks.append(buf)

    return chunks if chunks else [normalized]


def synth_chunks_to_wav(
    chunks: list, speaker_wav: str, out_wav: str, gpu: bool, gap_ms: int = 150
) -> None:
    """Load XTTS once, synth each chunk to a tempfile, concat the WAVs in
    memory with short silence gaps, write a single WAV to out_wav."""
    tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2", gpu=gpu)

    parts = []
    sr = None
    with tempfile.TemporaryDirectory() as td:
        for i, chunk in enumerate(chunks):
            chunk_wav = os.path.join(td, f"chunk_{i:03d}.wav")
            print(f"Chunk {i + 1}/{len(chunks)} ({len(chunk)} chars)...")
            tts.tts_to_file(
                text=chunk,
                speaker_wav=speaker_wav,
                language="en",
                file_path=chunk_wav,
            )
            data, this_sr = sf.read(chunk_wav, dtype="float32")
            if sr is None:
                sr = this_sr
            parts.append(data)

    gap = np.zeros(int(sr * gap_ms / 1000), dtype=parts[0].dtype)
    pieces = []
    for i, p in enumerate(parts):
        if i > 0:
            pieces.append(gap)
        pieces.append(p)
    merged = np.concatenate(pieces)

    sf.write(out_wav, merged, sr, subtype="PCM_16")


def synth_to_file(text: str, speaker_wav: str, out_wav: str, gpu: bool) -> None:
    """
    Synthesize to out_wav. If gpu=True and CUDA is available, attempt GPU.
    Long texts are split into <=250-char chunks, synthesized with the model
    loaded once, and concatenated before SoX post-processing.
    """
    chunks = split_text_for_xtts(text)
    if len(chunks) == 1:
        tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2", gpu=gpu)
        tts.tts_to_file(
            text=text,
            speaker_wav=speaker_wav,
            language="en",
            file_path=out_wav,
        )
        return
    print(f"Text exceeds single-chunk limit; splitting into {len(chunks)} chunks.")
    synth_chunks_to_wav(chunks, speaker_wav, out_wav, gpu)


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
    except (torch.OutOfMemoryError, RuntimeError) as e:
        msg = str(e).lower()
        if not isinstance(e, torch.OutOfMemoryError) and not (
            "cuda" in msg or "cublas" in msg or "out of memory" in msg
        ):
            raise
        print(f"CUDA failure during synthesis ({type(e).__name__}); falling back to CPU.")
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

