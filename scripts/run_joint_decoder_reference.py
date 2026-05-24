#!/usr/bin/env python3
"""
Compares CTC-only greedy decoding against joint CTC + transformer beam search
on the same WAVs. The goal is to decide whether wiring the transformer decoder
into the Dart pipeline is worth the implementation cost.

Mirrors the Dart preprocessing (power spectrum, natural log, utterance MVN).

Run from repo root:
    python3 scripts/run_joint_decoder_reference.py
"""
import sys
import time
from pathlib import Path

import librosa
import numpy as np
import onnxruntime as ort
import soundfile as sf

REPO = Path(__file__).resolve().parent.parent
MODEL_ROOT = REPO / "assets/EnglishGigaspeechConformerFBank_M01/full"
VOCAB = REPO / "assets/EnglishGigaspeechConformerFBank_M01/vocab.txt"

SR = 16_000
N_FFT = 512
WIN = 400
HOP = 160
N_MELS = 80
EPS = 1e-10
PAD = WIN // 2
BLANK_ID = 0
SOS_EOS_ID = 4999
UNK_ID = 1
BOUNDARY = "▁"
BEAM_SIZE = 5
CTC_WEIGHT = 0.3
DEC_WEIGHT = 0.7

DEFAULT_WAVS = [
    REPO / "assets/recordings/100007.wav",
    REPO / "assets/recordings/100009.wav",
]


def load_audio_16k_mono(path):
    audio, sr = sf.read(path)
    if audio.ndim > 1:
        audio = audio.mean(axis=1)
    audio = audio.astype(np.float64)
    if sr != SR:
        audio = librosa.resample(audio, orig_sr=sr, target_sr=SR)
    return audio


def log_mel(audio):
    padded = np.pad(audio, PAD, mode="reflect")
    window = 0.5 * (1.0 - np.cos(2.0 * np.pi * np.arange(WIN) / WIN))
    mel_fb = librosa.filters.mel(sr=SR, n_fft=N_FFT, n_mels=N_MELS, fmin=0.0, fmax=8000.0, htk=False, norm="slaney")
    n = (padded.size - WIN) // HOP + 1
    out = np.empty((n, N_MELS), dtype=np.float32)
    half = (N_FFT - WIN) // 2
    pre = np.zeros(half)
    post = np.zeros(N_FFT - WIN - half)
    for t in range(n):
        seg = padded[t * HOP : t * HOP + WIN] * window
        fft = np.fft.rfft(np.concatenate([pre, seg, post]), n=N_FFT)
        out[t] = np.log(mel_fb @ (fft.real ** 2 + fft.imag ** 2) + EPS)
    return out


def utterance_mvn(x):
    return x - x.mean(axis=0, keepdims=True)


def greedy_ctc(logits):
    pred = logits.argmax(axis=-1)
    out, prev = [], -1
    for tok in pred:
        if tok != prev and tok != BLANK_ID:
            out.append(int(tok))
        prev = int(tok)
    return out


def log_softmax(x, axis=-1):
    m = x.max(axis=axis, keepdims=True)
    e = np.exp(x - m)
    return (x - m) - np.log(e.sum(axis=axis, keepdims=True))


def joint_beam_decode(enc_out, ctc_logits, dec_sess, vocab_size):
    """Simple joint CTC + transformer beam search. enc_out is (1, T, 512)."""
    T = enc_out.shape[1]
    ctc_logp = log_softmax(ctc_logits[0], axis=-1)  # (T, V)

    # Approximate CTC contribution by total log-prob of best non-blank alignment
    # for each candidate sequence. For simplicity here, we use per-step max log-prob
    # of non-blank tokens summed up to length t of the hypothesis. This is a rough
    # approximation; the real espnet uses prefix scoring across alignments.
    nonblank_ctc = ctc_logp.copy()
    nonblank_ctc[:, BLANK_ID] = -1e9

    # Active beams: list of (prefix_tokens, caches, score)
    in_names = [i.name for i in dec_sess.get_inputs()]
    out_names = [o.name for o in dec_sess.get_outputs()]
    num_layers = len(in_names) - 2  # tgt, memory, plus caches
    dec_dim = 512

    def empty_cache():
        return [np.zeros((1, 0, dec_dim), dtype=np.float32) for _ in range(num_layers)]

    beams = [([SOS_EOS_ID], empty_cache(), 0.0)]
    finished = []

    max_len = int(T * 0.5) + 5  # CTC downsamples 4x, transcript at most ~T/8 tokens
    for step in range(max_len):
        cands = []
        for tokens, caches, score in beams:
            tgt = np.array([tokens], dtype=np.int64)
            feeds = {in_names[0]: tgt, in_names[1]: enc_out}
            for i, c in enumerate(caches):
                feeds[in_names[i + 2]] = c
            outs = dec_sess.run(out_names, feeds)
            logp = outs[0]  # may be (1, V) or (V,) depending on export
            new_caches = outs[1:]
            if logp.ndim == 2:
                logp = logp[-1]
            # Pick top-k tokens (excluding blank)
            topk = np.argsort(logp)[::-1][: BEAM_SIZE * 2]
            for tok in topk:
                if tok == BLANK_ID:
                    continue
                tok = int(tok)
                new_tokens = tokens + [tok]
                ctc_step = nonblank_ctc[min(step, T - 1), tok] if tok != SOS_EOS_ID else 0.0
                new_score = score + DEC_WEIGHT * float(logp[tok]) + CTC_WEIGHT * float(ctc_step)
                if tok == SOS_EOS_ID:
                    finished.append((new_tokens, new_score / max(1, len(new_tokens))))
                else:
                    cands.append((new_tokens, new_caches, new_score))
        if not cands:
            break
        cands.sort(key=lambda x: x[2], reverse=True)
        beams = cands[:BEAM_SIZE]

    if finished:
        finished.sort(key=lambda x: x[1], reverse=True)
        best_tokens = finished[0][0]
    else:
        best_tokens = max(beams, key=lambda x: x[2])[0]

    # Strip sos/eos
    return [t for t in best_tokens if t != SOS_EOS_ID]


def detokenize(ids, vocab):
    pieces = [vocab[i] for i in ids if i not in (UNK_ID, SOS_EOS_ID, BLANK_ID)]
    joined = "".join(pieces).replace(BOUNDARY, " ").strip()
    while "  " in joined:
        joined = joined.replace("  ", " ")
    return joined


def main():
    wavs = [Path(p) for p in sys.argv[1:]] if len(sys.argv) > 1 else DEFAULT_WAVS
    vocab = [l for l in VOCAB.read_text().splitlines() if l]
    enc_sess = ort.InferenceSession(str(MODEL_ROOT / "default_encoder.onnx"), providers=["CPUExecutionProvider"])
    ctc_sess = ort.InferenceSession(str(MODEL_ROOT / "ctc.onnx"), providers=["CPUExecutionProvider"])
    dec_sess = ort.InferenceSession(str(MODEL_ROOT / "xformer_decoder.onnx"), providers=["CPUExecutionProvider"])

    for wav in wavs:
        if not wav.exists():
            print(f"missing: {wav}")
            continue
        print(f"\n=== {wav.name} ===")
        audio = load_audio_16k_mono(wav)
        feats = utterance_mvn(log_mel(audio)).astype(np.float32)[None, ...]

        t0 = time.perf_counter()
        enc_out = enc_sess.run(None, {"feats": feats})[0]
        t_enc = time.perf_counter() - t0

        t0 = time.perf_counter()
        ctc_out = ctc_sess.run(None, {"x": enc_out})[0]
        t_ctc = time.perf_counter() - t0

        t0 = time.perf_counter()
        ids_greedy = greedy_ctc(ctc_out[0])
        text_greedy = detokenize(ids_greedy, vocab)
        t_greedy = time.perf_counter() - t0

        t0 = time.perf_counter()
        ids_joint = joint_beam_decode(enc_out, ctc_out, dec_sess, vocab_size=5000)
        text_joint = detokenize(ids_joint, vocab)
        t_joint = time.perf_counter() - t0

        print(f"encoder: {t_enc*1000:.0f} ms, ctc: {t_ctc*1000:.0f} ms")
        print(f"CTC greedy ({t_greedy*1000:.0f} ms): {text_greedy!r}")
        print(f"Joint beam ({t_joint*1000:.0f} ms): {text_joint!r}")


if __name__ == "__main__":
    sys.exit(main())
