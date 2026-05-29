"""
Export an ESPnet ASR model to ONNX and package it as an .asrmodel file.

Usage:
    python export.py [--tag TAG] [--output OUTPUT] [--no-package]

Options:
    --tag TAG        HuggingFace model tag (default: YuanyuanZhang/EnglishGigaspeechConformerFBank_M01)
    --output OUTPUT  Output .asrmodel path, or an existing directory in which
                     to write <model_name>.asrmodel (default: cwd)
    --no-package     Skip packaging; only export ONNX files to the cache directory

Prerequisites:
    pip install --no-build-isolation --no-deps -r requirements.txt
    python apply_patches.py
"""

import argparse
from pathlib import Path

from espnet_onnx.export import ASRModelExport
from espnet_model_zoo.downloader import ModelDownloader

DEFAULT_TAG = "YuanyuanZhang/EnglishGigaspeechConformerFBank_M01"


def export_model(tag: str, cache_dir: Path) -> Path:
    downloaded = ModelDownloader().download_and_unpack(tag)
    snapshot_root = Path(downloaded["asr_train_config"]).parent.parent.parent

    bpe_candidates = list(snapshot_root.rglob("bpe.model"))
    if not bpe_candidates:
        raise FileNotFoundError(f"bpe.model not found under {snapshot_root}")
    bpemodel = str(bpe_candidates[0])
    print(f"Using bpemodel: {bpemodel}")

    m = ASRModelExport(cache_dir=cache_dir)
    print("Starting ONNX export — this will take 5–10 minutes...")
    m.export_from_pretrained(
        tag,
        quantize=False,
        pretrained_config={"bpemodel": bpemodel},
    )
    print("ONNX export complete.")

    tag_dir = cache_dir / tag
    return tag_dir


def main() -> None:
    parser = argparse.ArgumentParser(description="Export ESPnet model to .asrmodel")
    parser.add_argument("--tag", default=DEFAULT_TAG, help="HuggingFace model tag")
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Output .asrmodel path, or an existing directory to write into",
    )
    parser.add_argument("--no-package", action="store_true", help="Skip packaging step")
    args = parser.parse_args()

    cache_dir = Path.home() / ".cache" / "espnet_onnx"
    cache_dir.mkdir(parents=True, exist_ok=True)

    export_dir = export_model(args.tag, cache_dir)

    if not args.no_package:
        from package_model import package_model

        model_name = args.tag.split("/")[-1]
        output = args.output or Path(f"{model_name}.asrmodel")
        # If --output points at a directory, write into it.
        if output.is_dir():
            output = output / f"{model_name}.asrmodel"
        package_model(export_dir, model_name, output)


if __name__ == "__main__":
    main()
