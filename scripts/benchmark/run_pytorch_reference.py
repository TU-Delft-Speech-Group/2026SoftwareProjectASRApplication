#!/usr/bin/env python3
"""
Reference inference on the corpus benchmark WAVs using the original
PyTorch model. Loads the requested HuggingFace tag via espnet's
Speech2Text and runs each English corpus WAV end-to-end (no streaming,
no chunking). The hypotheses are written to a JSON file so we can
diff them against the Flutter streaming pipeline's output.

Run from repo root with the espnet venv:
    python scripts/benchmark/run_pytorch_reference.py \
        [out_path] [hf_tag]

Defaults to writing /tmp/pytorch_reference.json with the M01Libri100
model loaded.
"""

import json
import sys
import time
from pathlib import Path

import numpy as np
import soundfile as sf
from espnet_model_zoo.downloader import ModelDownloader
from espnet2.bin.asr_inference import Speech2Text

REPO = Path(__file__).resolve().parent.parent.parent
CORPUS_DIR = REPO / "assets/audio/English/Spon0513"
DEFAULT_TAG = "YuanyuanZhang/EnglishGigaspeechConformerFBank_M01Libri100"


def resolve_local_paths(tag: str) -> dict:
    """Download the HF model and return the local cache paths, including a
    bpemodel override (the config.yaml inside the .pth references a
    /tudelft.net/... path that doesn't exist locally)."""
    info = ModelDownloader().download_and_unpack(tag)
    snapshot_root = Path(info["asr_train_config"]).parent.parent.parent
    bpe_candidates = list(snapshot_root.rglob("bpe.model"))
    if not bpe_candidates:
        raise SystemExit(f"no bpe.model under {snapshot_root}")
    return {
        "asr_train_config": info["asr_train_config"],
        "asr_model_file": info["asr_model_file"],
        "bpemodel": str(bpe_candidates[0]),
    }


def load_corpus(set_dir: Path):
    text_file = set_dir / "text"
    if not text_file.exists():
        raise SystemExit(f"missing: {text_file}")
    entries = []
    for line in text_file.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split(None, 1)
        if len(parts) != 2:
            continue
        uid, transcript = parts
        wav = set_dir / f"{uid}.wav"
        if not wav.exists():
            continue
        entries.append((uid, transcript, wav))
    return entries


def load_audio_16k_mono(path: Path) -> np.ndarray:
    audio, sr = sf.read(str(path))
    if audio.ndim > 1:
        audio = audio.mean(axis=1)
    audio = audio.astype(np.float32)
    if sr != 16_000:
        import librosa
        audio = librosa.resample(audio, orig_sr=sr, target_sr=16_000)
    return audio


def main():
    out_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/tmp/pytorch_reference.json")
    tag = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_TAG

    print(f"loading model: {tag}", file=sys.stderr)
    paths = resolve_local_paths(tag)
    # beam_size=1 to match what our streaming pipeline uses for englishGigaspeech.
    # ctc_weight defaults to 0.5 in espnet (joint CTC+attention).
    speech2text = Speech2Text(
        asr_train_config=paths["asr_train_config"],
        asr_model_file=paths["asr_model_file"],
        bpemodel=paths["bpemodel"],
        token_type="bpe",
        beam_size=1,
        device="cpu",
    )

    entries = load_corpus(CORPUS_DIR)
    print(f"{len(entries)} corpus entries", file=sys.stderr)

    results = []
    total_start = time.time()
    for i, (uid, transcript, wav_path) in enumerate(entries):
        audio = load_audio_16k_mono(wav_path)
        t0 = time.time()
        try:
            nbests = speech2text(audio)
            hyp = nbests[0][0] if nbests else ""
            err = None
        except Exception as e:
            hyp = ""
            err = str(e)
        dt_ms = int((time.time() - t0) * 1000)

        print(
            f"[{i + 1}/{len(entries)}] {uid} ({dt_ms}ms) "
            f"truth={transcript!r} hyp={hyp!r}"
            + (f" ERR={err}" if err else "")
        )
        results.append({
            "id": uid,
            "truth": transcript,
            "hypothesis": hyp,
            "ms": dt_ms,
            "error": err,
        })

    total_s = int(time.time() - total_start)
    out_path.write_text(json.dumps(results, indent=2))
    print(
        f"wrote {len(results)} results to {out_path} (total {total_s}s)",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
