"""
Package an ESPnet ONNX export directory into an .asrmodel file.

An .asrmodel file is a ZIP archive containing:
  manifest.json  — metadata and SHA-256 checksums for all included files
  encoder.onnx   — required
  ctc.onnx       — required
  vocab.txt      — required (generated from config.yaml token.list / token_list if not present)
  decoder.onnx   — optional (included when xformer_decoder.onnx is present)

Usage:
    python package_model.py <export_dir> <model_name> [--output <path>]

Arguments:
    export_dir   Path to the ESPnet ONNX export directory
                 (must contain a full/ subdirectory with the exported ONNX files
                  and a config.yaml or vocab.txt at the top level)
    model_name   Identifier string for this model (used as the directory name
                 when the app installs the package)

Options:
    --output     Output path (default: <model_name>.asrmodel in the current directory)
"""

import argparse
import hashlib
import json
import zipfile
from pathlib import Path

FORMAT_VERSION = "1"
EXTENSION = ".asrmodel"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def resolve_vocab(export_dir: Path) -> Path:
    """Return path to vocab.txt, generating it from config.yaml if needed."""
    for candidate in [export_dir / "vocab.txt", export_dir / "full" / "vocab.txt"]:
        if candidate.exists():
            return candidate

    # Generate vocab.txt from the vocabulary in config.yaml
    config_path = export_dir / "config.yaml"
    if not config_path.exists():
        raise FileNotFoundError(
            f"Neither vocab.txt nor config.yaml found in {export_dir}. "
            "Cannot determine token vocabulary."
        )

    try:
        import yaml
    except ImportError:
        raise ImportError(
            "PyYAML is required to generate vocab.txt from config.yaml. "
            "It is already in requirements.txt — make sure your venv is active."
        )

    with open(config_path, "r", encoding="utf-8") as f:
        config = yaml.safe_load(f)

    # espnet_onnx writes the vocabulary under `token.list`; older formats
    # used a top-level `token_list`. Accept either.
    token_list = config.get("token_list")
    if not token_list:
        token_section = config.get("token")
        if isinstance(token_section, dict):
            token_list = token_section.get("list")
    if not token_list:
        raise KeyError(
            "config.yaml does not contain a token vocabulary "
            "(checked 'token.list' and 'token_list'). "
            "Cannot generate vocab.txt automatically."
        )

    vocab_path = export_dir / "vocab.txt"
    vocab_path.write_text("\n".join(token_list), encoding="utf-8")
    print(f"Generated vocab.txt from config.yaml ({len(token_list)} tokens)")
    return vocab_path


def package_model(export_dir: Path, model_name: str, output_path: Path) -> None:
    full_dir = export_dir / "full"

    encoder = full_dir / "default_encoder.onnx"
    ctc = full_dir / "ctc.onnx"
    vocab = resolve_vocab(export_dir)
    decoder = full_dir / "xformer_decoder.onnx"

    for path in [encoder, ctc]:
        if not path.exists():
            raise FileNotFoundError(f"Required ONNX file not found: {path}")

    has_decoder = decoder.exists()

    file_entries: dict[str, dict] = {
        "encoder.onnx": {"required": True, "sha256": sha256_file(encoder)},
        "ctc.onnx": {"required": True, "sha256": sha256_file(ctc)},
        "vocab.txt": {"required": True, "sha256": sha256_file(vocab)},
    }
    if has_decoder:
        file_entries["decoder.onnx"] = {
            "required": False,
            "sha256": sha256_file(decoder),
        }

    manifest = {
        "format_version": FORMAT_VERSION,
        "model_name": model_name,
        "has_decoder": has_decoder,
        "files": file_entries,
    }

    with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("manifest.json", json.dumps(manifest, indent=2))
        zf.write(encoder, "encoder.onnx")
        zf.write(ctc, "ctc.onnx")
        zf.write(vocab, "vocab.txt")
        if has_decoder:
            zf.write(decoder, "decoder.onnx")

    size_mb = output_path.stat().st_size / 1_048_576
    print(f"\nPackaged -> {output_path}  ({size_mb:.1f} MB)")
    for name, info in file_entries.items():
        tag = "required" if info["required"] else "optional"
        print(f"  {name}  [{tag}]  sha256:{info['sha256'][:16]}...")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Package an ESPnet ONNX export directory into an .asrmodel file"
    )
    parser.add_argument("export_dir", type=Path, help="ESPnet ONNX export directory")
    parser.add_argument("model_name", help="Model identifier (e.g. EnglishGigaspeechConformerFBank_M01)")
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Output file path, or an existing directory to write into "
        "(default: <model_name>.asrmodel in the current directory)",
    )
    args = parser.parse_args()

    output = args.output or Path(f"{args.model_name}{EXTENSION}")
    # If --output points at a directory, write into it.
    if output.is_dir():
        output = output / f"{args.model_name}{EXTENSION}"
    package_model(args.export_dir.resolve(), args.model_name, output.resolve())


if __name__ == "__main__":
    main()
