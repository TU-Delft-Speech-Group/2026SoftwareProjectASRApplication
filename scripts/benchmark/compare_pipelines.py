#!/usr/bin/env python3
"""
Diff PyTorch reference output against the Flutter streaming pipeline's log
and report per-utterance + aggregate WER for each. Highlights where the
streaming pipeline lost information that PyTorch had.

Usage:
    python scripts/benchmark/compare_pipelines.py \
        /tmp/pytorch_ref_libri100.json \
        /tmp/bench_full_v4.log
"""

import json
import re
import string
import sys
from pathlib import Path


def normalise(text: str) -> list[str]:
    text = text.lower()
    text = text.translate(str.maketrans({c: " " for c in string.punctuation}))
    return [t for t in text.split() if t]


def edit_ops(ref: list[str], hyp: list[str]) -> tuple[int, int, int]:
    m, n = len(ref), len(hyp)
    dp = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(m + 1):
        dp[i][0] = i
    for j in range(n + 1):
        dp[0][j] = j
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if ref[i - 1] == hyp[j - 1]:
                dp[i][j] = dp[i - 1][j - 1]
            else:
                dp[i][j] = 1 + min(dp[i - 1][j - 1], dp[i][j - 1], dp[i - 1][j])
    i, j = m, n
    subs = ins = dels = 0
    while i > 0 or j > 0:
        if i > 0 and j > 0 and ref[i - 1] == hyp[j - 1]:
            i -= 1
            j -= 1
        elif i > 0 and j > 0 and dp[i][j] == dp[i - 1][j - 1] + 1:
            subs += 1
            i -= 1
            j -= 1
        elif j > 0 and dp[i][j] == dp[i][j - 1] + 1:
            ins += 1
            j -= 1
        else:
            dels += 1
            i -= 1
    return subs, ins, dels


def wer(truth: str, hyp: str) -> tuple[float, int, int, int, int]:
    ref = normalise(truth)
    hyp_tok = normalise(hyp)
    if not ref:
        return 1.0 if hyp_tok else 0.0, 0, 0, 0, 0
    subs, ins, dels = edit_ops(ref, hyp_tok)
    return (subs + ins + dels) / len(ref), subs, ins, dels, len(ref)


def parse_flutter(log_path: Path) -> dict[str, dict]:
    pattern = re.compile(
        r"\[\d+/\d+\]\s+(M01-D09-\d+)\s+\((\d+)ms\)\s+WER=([\d.]+)\s+hyp=\"([^\"]*)\""
    )
    out = {}
    for line in log_path.read_text().splitlines():
        m = pattern.search(line)
        if not m:
            continue
        out[m.group(1)] = {
            "ms": int(m.group(2)),
            "wer": float(m.group(3)),
            "hyp": m.group(4),
        }
    return out


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    pt_path = Path(sys.argv[1])
    fl_path = Path(sys.argv[2])

    pt_data = json.loads(pt_path.read_text())
    fl_data = parse_flutter(fl_path)

    pt_totals = [0, 0, 0, 0]  # subs, ins, dels, ref_words
    fl_totals = [0, 0, 0, 0]
    pt_ms_total = 0
    fl_ms_total = 0

    rows = []
    for entry in pt_data:
        uid = entry["id"]
        truth = entry["truth"]
        pt_hyp = entry["hypothesis"]
        pt_ms = entry["ms"]
        pt_w, ps, pi, pd, refn = wer(truth, pt_hyp)
        pt_totals[0] += ps
        pt_totals[1] += pi
        pt_totals[2] += pd
        pt_totals[3] += refn
        pt_ms_total += pt_ms

        fl_entry = fl_data.get(uid)
        fl_hyp = fl_entry["hyp"] if fl_entry else ""
        fl_ms = fl_entry["ms"] if fl_entry else 0
        fl_w, fs, fi, fd, _ = wer(truth, fl_hyp)
        fl_totals[0] += fs
        fl_totals[1] += fi
        fl_totals[2] += fd
        fl_totals[3] += refn
        fl_ms_total += fl_ms

        rows.append({
            "id": uid,
            "truth": truth,
            "pt_hyp": pt_hyp,
            "pt_wer": pt_w,
            "pt_ms": pt_ms,
            "fl_hyp": fl_hyp,
            "fl_wer": fl_w,
            "fl_ms": fl_ms,
            "delta": fl_w - pt_w,
        })

    rows.sort(key=lambda r: -r["delta"])

    print("=" * 100)
    print(f"{'AGGREGATE':<20} {'PyTorch':>20} {'Flutter':>20}")
    print(f"{'WER':<20} {sum(pt_totals[:3]) / pt_totals[3]:>20.3f} "
          f"{sum(fl_totals[:3]) / fl_totals[3]:>20.3f}")
    print(f"{'subs':<20} {pt_totals[0]:>20d} {fl_totals[0]:>20d}")
    print(f"{'inserts':<20} {pt_totals[1]:>20d} {fl_totals[1]:>20d}")
    print(f"{'deletes':<20} {pt_totals[2]:>20d} {fl_totals[2]:>20d}")
    print(f"{'ref words':<20} {pt_totals[3]:>20d} {fl_totals[3]:>20d}")
    print(f"{'total time (s)':<20} {pt_ms_total / 1000:>20.1f} {fl_ms_total / 1000:>20.1f}")
    print()
    print("Top 15 biggest pipeline-vs-pytorch deltas (flutter WER - pytorch WER):")
    print(f"{'id':<14} {'delta':>7} {'pt_wer':>7} {'fl_wer':>7}  truth")
    print(f"{'':<14} {'':<22}  pytorch hyp")
    print(f"{'':<14} {'':<22}  flutter hyp")
    print("-" * 100)
    for r in rows[:15]:
        print(f"{r['id']:<14} {r['delta']:>+7.3f} {r['pt_wer']:>7.3f} {r['fl_wer']:>7.3f}  {r['truth']}")
        print(f"{'':14} {'':22}  pt: {r['pt_hyp']}")
        print(f"{'':14} {'':22}  fl: {r['fl_hyp']}")
        print()


if __name__ == "__main__":
    main()
