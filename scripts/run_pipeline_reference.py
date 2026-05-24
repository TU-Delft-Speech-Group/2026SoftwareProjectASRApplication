#!/usr/bin/env python3
"""
End-to-end ASR pipeline reference in Python, used to validate the Dart
implementation against the same ONNX models.

For each WAV passed on the command line (or the default set below), the
script:
  * Resamples to 16 kHz mono if needed.
  * Computes log-mel features the same way the Dart MelService does
    (power spectrum, slaney mel filterbank, natural log).
  * Applies utterance-MVN.
  * Runs the Gigaspeech encoder + CTC ONNX models.
  * Greedy-decodes the CTC output and prints the predicted transcript.

Run from repo root with the project's python venv:
    python3 scripts/run_pipeline_reference.py
    python3 scripts/run_pipeline_reference.py assets/recordings/100007.wav
"""
import sys
from pathlib import Path

import librosa
import numpy as np
import onnxruntime as ort
import soundfile as sf

REPO = Path(__file__).resolve().parent.parent
MODEL_ROOT = REPO / "assets/EnglishGigaspeechConformerFBank_M01"
ENCODER = MODEL_ROOT / "full/default_encoder.onnx"
CTC = MODEL_ROOT / "full/ctc.onnx"
VOCAB = MODEL_ROOT / "vocab.txt"

SR = 16_000
N_FFT = 512
WIN = 400
HOP = 160
N_MELS = 80
EPS = 1e-10
PAD = WIN // 2
BLANK_ID = 0
EOS_ID = 4999
UNK_ID = 1
BOUNDARY = "▁"

DEFAULT_WAVS = [
    REPO / "assets/recordings/100007.wav",
    REPO / "assets/recordings/100009.wav",
]


def load_audio_16k_mono(path: Path) -> np.ndarray:
    audio, sr = sf.read(path)
    if audio.ndim > 1:
        audio = audio.mean(axis=1)
    audio = audio.astype(np.float64)
    if sr != SR:
        audio = librosa.resample(audio, orig_sr=sr, target_sr=SR)
    return audio


def log_mel(audio: np.ndarray) -> np.ndarray:
    padded = np.pad(audio, PAD, mode="reflect")
    window = 0.5 * (1.0 - np.cos(2.0 * np.pi * np.arange(WIN) / WIN))
    mel_fb = librosa.filters.mel(
        sr=SR, n_fft=N_FFT, n_mels=N_MELS, fmin=0.0, fmax=8000.0, htk=False, norm="slaney"
    )
    n_frames = (padded.size - WIN) // HOP + 1
    out = np.empty((n_frames, N_MELS), dtype=np.float32)
    half_pad = (N_FFT - WIN) // 2
    pre = np.zeros(half_pad)
    post = np.zeros(N_FFT - WIN - half_pad)
    for t in range(n_frames):
        start = t * HOP
        seg = padded[start : start + WIN] * window
        centered = np.concatenate([pre, seg, post])
        fft = np.fft.rfft(centered, n=N_FFT)
        power = fft.real ** 2 + fft.imag ** 2
        out[t] = np.log(mel_fb @ power + EPS)
    return out


def utterance_mvn(feats: np.ndarray) -> np.ndarray:
    return feats - feats.mean(axis=0, keepdims=True)


def greedy_ctc(logits: np.ndarray) -> list[int]:
    # logits: (T, V) log-probs or raw scores; argmax then collapse repeats and blank.
    pred = logits.argmax(axis=-1)
    out: list[int] = []
    prev = -1
    for token in pred:
        if token != prev and token != BLANK_ID:
            out.append(int(token))
        prev = int(token)
    return out


def load_vocab() -> list[str]:
    return [line for line in VOCAB.read_text().splitlines() if line]


def detokenize(ids: list[int], vocab: list[str]) -> str:
    pieces = [vocab[i] for i in ids if i not in (UNK_ID, EOS_ID)]
    joined = "".join(pieces).replace(BOUNDARY, " ").strip()
    while "  " in joined:
        joined = joined.replace("  ", " ")
    return joined


def run(wav: Path, encoder_sess: ort.InferenceSession, ctc_sess: ort.InferenceSession, vocab: list[str]) -> None:
    print(f"\n=== {wav.name} ===")
    audio = load_audio_16k_mono(wav)
    print(f"audio: {audio.size} samples ({audio.size / SR:.2f} s)")
    feats = log_mel(audio)
    print(f"log-mel shape: {feats.shape}, range=[{feats.min():.2f}, {feats.max():.2f}]")
    feats_mvn = utterance_mvn(feats).astype(np.float32)
    print(f"after MVN: mean={feats_mvn.mean():.2e} std={feats_mvn.std():.2f}")

    enc_in = feats_mvn[np.newaxis, ...]  # (1, T, 80)
    enc_outs = encoder_sess.run(None, {"feats": enc_in})
    enc_out = enc_outs[0]
    print(f"encoder out shape: {enc_out.shape}")

    ctc_out = ctc_sess.run(None, {"x": enc_out})[0]  # (1, T', V)
    print(f"ctc out shape: {ctc_out.shape}")

    ids = greedy_ctc(ctc_out[0])
    text = detokenize(ids, vocab)
    print(f"transcript: {text!r}")


def main() -> int:
    wavs = [Path(p) for p in sys.argv[1:]] if len(sys.argv) > 1 else DEFAULT_WAVS
    vocab = load_vocab()
    encoder_sess = ort.InferenceSession(str(ENCODER), providers=["CPUExecutionProvider"])
    ctc_sess = ort.InferenceSession(str(CTC), providers=["CPUExecutionProvider"])

    for wav in wavs:
        if not wav.exists():
            print(f"missing wav: {wav}")
            continue
        run(wav, encoder_sess, ctc_sess, vocab)

    return 0


if __name__ == "__main__":
    sys.exit(main())
