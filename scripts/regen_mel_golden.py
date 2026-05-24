#!/usr/bin/env python3
"""
Regenerates the mel-spectrogram golden file used by
test/services/audio/audio_service_test.dart.

NOTE: vocab.txt files for both shipped models can be extracted with
    python -c "import yaml; d=yaml.safe_load(open(SRC)); open(DST,'w').write('\\n'.join(d['token']['list'])+'\\n')"
where SRC is the model's config.yaml.

The reference matches the current Dart MelService + WindowingService pipeline:
  * PCM16 normalized to [-1, 1]
  * 200-sample reflect padding at both ends (np.pad mode='reflect', pad=200)
  * Sliding window: length 400, hop 160
  * Periodic Hann(400) window function
  * Center-pad each windowed frame to 512 (zeros on both sides)
  * Real FFT of 512
  * Power spectrum
  * Slaney-normalized mel filterbank (80 bins, fmin=0, fmax=8000, sr=16k)
  * Natural log of (mel + 1e-10)

Run from repo root with the project's python venv:
    python3 scripts/regen_mel_golden.py
"""
import json
import sys
from pathlib import Path

import librosa
import numpy as np
import soundfile as sf

REPO = Path(__file__).resolve().parent.parent
WAV = REPO / "test/assets/poisoned_potato_test.wav"
OUT = REPO / "test/services/audio/golden/espnet_mel_spectrogram_tests_poisoned_potato_test_wav.json"

SR = 16_000
N_FFT = 512
WIN = 400
HOP = 160
N_MELS = 80
EPS = 1e-10
PAD = WIN // 2  # 200, matches WindowingService._centerPad


def hann_periodic(n: int) -> np.ndarray:
    return 0.5 * (1.0 - np.cos(2.0 * np.pi * np.arange(n) / n))


def center_pad(seg: np.ndarray, target: int) -> np.ndarray:
    diff = target - seg.size
    left = diff // 2
    right = diff - left
    return np.concatenate([np.zeros(left, dtype=seg.dtype), seg, np.zeros(right, dtype=seg.dtype)])


def main() -> int:
    audio, sr = sf.read(WAV, dtype="int16")
    if sr != SR:
        raise SystemExit(f"unexpected sample rate {sr} for {WAV}")
    audio = audio.astype(np.float64) / 32768.0

    padded = np.pad(audio, PAD, mode="reflect")
    window = hann_periodic(WIN)
    mel_fb = librosa.filters.mel(
        sr=SR, n_fft=N_FFT, n_mels=N_MELS, fmin=0.0, fmax=8000.0, htk=False, norm="slaney"
    )

    n_frames = (padded.size - WIN) // HOP + 1
    log_mel = np.empty((n_frames, N_MELS), dtype=np.float64)
    for t in range(n_frames):
        start = t * HOP
        seg = padded[start : start + WIN] * window
        fft = np.fft.rfft(center_pad(seg, N_FFT), n=N_FFT)
        power = (fft.real ** 2 + fft.imag ** 2)
        mel = mel_fb @ power
        log_mel[t] = np.log(mel + EPS)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(log_mel.tolist()))
    print(f"wrote {n_frames} frames x {N_MELS} mels -> {OUT.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
