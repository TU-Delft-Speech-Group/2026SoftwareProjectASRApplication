"""Overlay local fixes onto the installed espnet_onnx package.

Run this once after `pip install espnet_onnx`, and again after any upgrade
that re-installs the package.
"""
import importlib.util
import shutil
import sys
from pathlib import Path

PATCHES = {
    "xformer.py": "export/asr/models/decoders/xformer.py",
    "convert_map.yml": "export/convert_map.yml",
}


def find_espnet_onnx_root() -> Path:
    spec = importlib.util.find_spec("espnet_onnx")
    if spec is None or spec.origin is None:
        sys.exit("espnet_onnx is not installed in this Python environment.")
    return Path(spec.origin).parent


def main() -> None:
    here = Path(__file__).resolve().parent
    patches_dir = here / "patches"
    target_root = find_espnet_onnx_root()

    print(f"Patching espnet_onnx at: {target_root}")
    for source_name, relative_target in PATCHES.items():
        source = patches_dir / source_name
        target = target_root / relative_target
        if not source.exists():
            sys.exit(f"Missing patch source: {source}")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(source, target)
        print(f"  wrote {target}")

    print("Done.")


if __name__ == "__main__":
    main()
