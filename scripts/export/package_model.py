"""
Package an ESPnet ONNX export directory into an .asrmodel file.

An .asrmodel file is a ZIP archive containing:
  manifest.json  — metadata, vocab token ids, and SHA-256 checksums
  encoder.onnx   — required
  ctc.onnx       — required
  vocab.txt      — required (generated from config.yaml token.list / token_list if not present)
  decoder.onnx   — optional (included when xformer_decoder.onnx is present)

manifest.json also carries a "vocab" block with the special-token ids the app
needs to decode correctly (blank, unk, sos/eos, and the non-speech filler
tokens to suppress). These are detected from the token list and can be
overridden with the --blank-id / --unk-id / --sos-eos-id / --suppressed-ids /
--word-boundary-marker flags when a model breaks the usual ESPnet conventions.

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

# Bump to "2": manifests now include the "vocab" metadata block. The app still
# accepts version "1" packages (no block) by falling back to built-in defaults.
FORMAT_VERSION = "2"
EXTENSION = ".asrmodel"


def _is_special_token(token: str) -> bool:
    """A token wrapped in <…> or […] — ESPnet's convention for non-vocabulary
    markers (<blank>, <unk>, <sos/eos>, [FIL], [LAUGH], [UNK], …). Real BPE
    pieces carry the ▁ word-boundary marker instead, never these brackets."""
    return (token.startswith("<") and token.endswith(">")) or (
        token.startswith("[") and token.endswith("]")
    )


def detect_vocab_metadata(tokens: list[str], overrides: dict | None = None) -> dict:
    """Derive the special-token ids the app needs from the token list.

    index == token id. Detection follows standard ESPnet gigaspeech-recipe
    conventions; pass `overrides` (from CLI flags) to correct any field.

    `suppressed_ids` are the extra ids to drop from decoded text beyond
    unk/sos/eos (which the app already filters via their own fields): the CTC
    blank plus any bracketed non-speech markers such as [FIL]/[LAUGH]/[UNK].
    """
    overrides = overrides or {}

    def index_of(symbol: str):
        return tokens.index(symbol) if symbol in tokens else None

    blank_id = index_of("<blank>")
    if blank_id is None:
        blank_id = 0  # ESPnet CTC blank is conventionally id 0.

    unk_id = index_of("<unk>")
    if unk_id is None:
        print("WARNING: no <unk> token found; defaulting unk_id to 1.")
        unk_id = 1

    sos_eos_id = None
    for symbol in ("<sos/eos>", "<eos>", "</s>", "<sos>", "<s>"):
        sos_eos_id = index_of(symbol)
        if sos_eos_id is not None:
            break
    if sos_eos_id is None:
        sos_eos_id = len(tokens) - 1  # ESPnet places sos/eos last.

    special = {i for i, t in enumerate(tokens) if _is_special_token(t)}
    suppressed = sorted((special | {blank_id}) - {unk_id, sos_eos_id})

    word_boundary = "▁" if any(t.startswith("▁") for t in tokens) else None

    meta = {
        "blank_id": blank_id,
        "unk_id": unk_id,
        "sos_eos_id": sos_eos_id,
        "suppressed_ids": suppressed,
        "word_boundary_marker": word_boundary,
    }
    meta.update({k: v for k, v in overrides.items() if v is not None})
    return meta


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
    # newline="" disables platform newline translation so the file ships with
    # LF, not CRLF, on Windows — the app splits vocab.txt on "\n" and would
    # otherwise leave a stray "\r" on every token.
    vocab_path.write_text("\n".join(token_list), encoding="utf-8", newline="")
    print(f"Generated vocab.txt from config.yaml ({len(token_list)} tokens)")
    return vocab_path


def package_model(
    export_dir: Path,
    model_name: str,
    output_path: Path,
    vocab_overrides: dict | None = None,
) -> None:
    full_dir = export_dir / "full"

    encoder = full_dir / "default_encoder.onnx"
    ctc = full_dir / "ctc.onnx"
    vocab = resolve_vocab(export_dir)
    decoder = full_dir / "xformer_decoder.onnx"

    for path in [encoder, ctc]:
        if not path.exists():
            raise FileNotFoundError(f"Required ONNX file not found: {path}")

    has_decoder = decoder.exists()

    tokens = vocab.read_text(encoding="utf-8").splitlines()
    vocab_meta = detect_vocab_metadata(tokens, vocab_overrides)

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
        "vocab": vocab_meta,
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
    print("  vocab metadata:")
    for key, value in vocab_meta.items():
        # The word-boundary marker is ▁ (U+2581); escape non-ASCII so this
        # prints on consoles using legacy code pages (e.g. Windows cp1252).
        safe = str(value).encode("ascii", "backslashreplace").decode("ascii")
        print(f"    {key}: {safe}")


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
    # Vocab-metadata overrides — only needed when a model breaks the usual
    # ESPnet token conventions and auto-detection picks the wrong id.
    parser.add_argument("--blank-id", type=int, default=None, help="CTC blank token id")
    parser.add_argument("--unk-id", type=int, default=None, help="Unknown token id")
    parser.add_argument("--sos-eos-id", type=int, default=None, help="Start/end-of-sequence token id")
    parser.add_argument(
        "--suppressed-ids",
        type=str,
        default=None,
        help="Comma-separated token ids to drop from decoded text "
        "(blank + non-speech fillers), e.g. 0,2,3,4",
    )
    parser.add_argument(
        "--word-boundary-marker",
        type=str,
        default=None,
        help="SentencePiece word-boundary marker (default: ▁ when present)",
    )
    args = parser.parse_args()

    overrides: dict = {
        "blank_id": args.blank_id,
        "unk_id": args.unk_id,
        "sos_eos_id": args.sos_eos_id,
        "word_boundary_marker": args.word_boundary_marker,
    }
    if args.suppressed_ids is not None:
        overrides["suppressed_ids"] = [
            int(x) for x in args.suppressed_ids.split(",") if x.strip() != ""
        ]

    output = args.output or Path(f"{args.model_name}{EXTENSION}")
    # If --output points at a directory, write into it.
    if output.is_dir():
        output = output / f"{args.model_name}{EXTENSION}"
    package_model(
        args.export_dir.resolve(), args.model_name, output.resolve(), overrides
    )


if __name__ == "__main__":
    main()
