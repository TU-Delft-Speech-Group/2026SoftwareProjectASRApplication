# scripts/export — ESPnet → .asrmodel packaging toolchain

Converts an ESPnet PyTorch ASR model into an `.asrmodel` bundle that the app
can verify and load directly from device storage.

## Files

| File | Purpose |
|------|---------|
| `export.py` | Downloads and exports a model from HuggingFace, then packages it |
| `package_model.py` | Packages an already-exported ONNX directory into an `.asrmodel` file |
| `apply_patches.py` | Applies two bug-fix patches to the installed `espnet_onnx` package |
| `requirements.txt` | Frozen Python 3.10 dependency set |
| `patches/xformer.py` | Fixes the transformer decoder export (token slice + dummy input shape) |
| `patches/convert_map.yml` | Module-mapping file missing from the `espnet_onnx` PyPI release |
| `test_package_model.py` | Unit tests for `package_model.py` |

## Requirements

- **Python 3.10 exactly** — `torch 2.0.1` does not build against later versions.
- free disk space (model download + ONNX cache).
- The first export run downloads from HuggingFace; subsequent runs use the local cache.

## Setup

Run all commands from inside the `scripts/export/` directory.

**Windows (PowerShell):**
```powershell
python -m venv .venv           # use  py -3.10 -m venv .venv  if multiple Python versions are installed
.venv\Scripts\activate.bat     # use activate.bat to avoid PowerShell execution-policy errors
python -m pip install --no-build-isolation --no-deps -r requirements.txt
python apply_patches.py
```

> If you see *"running scripts is disabled on this system"*, either use `.venv\Scripts\activate.bat`
> (shown above) or run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` once
> to allow local scripts for your user.

> Use `python -m pip` rather than bare `pip`. On Windows, an outer `pip` shim
> (PowerShell alias, Python launcher entry, or a globally-installed `pip.exe`
> earlier in PATH) can shadow the venv's pip even when the prompt shows
> `(.venv)`. `python -m pip` always runs against the active interpreter.

**macOS / Linux:**
```sh
python3.10 -m venv .venv
source .venv/bin/activate
python -m pip install --no-build-isolation --no-deps -r requirements.txt
python apply_patches.py
```

> `--no-deps` is required because several packages in this frozen set have declared
> dependency constraints that conflict with each other (notably `lightning` requires
> `torch>=2.1.0` while we pin `torch==2.0.1`, and `espnet-onnx` pins `typeguard==2.13.0`
> while newer packages require `typeguard>=4`). All versions are explicitly pinned so
> pip does not need to resolve anything — the install works correctly at runtime.

`apply_patches.py` must be re-run after any reinstall or upgrade of `espnet_onnx`.

## Usage

Make sure the venv is activated before running any of the commands below.

### Export and package in one step

```sh
python export.py --tag YuanyuanZhang/EnglishGigaspeechConformerFBank_M01
```

This downloads the model (~3 GB), runs the ONNX export (~5–10 min), and
writes `EnglishGigaspeechConformerFBank_M01.asrmodel` in the current directory.

Options:

```
--tag TAG        HuggingFace model tag  (default: YuanyuanZhang/EnglishGigaspeechConformerFBank_M01)
--output PATH    Output .asrmodel path  (default: <model_name>.asrmodel)
--no-package     Stop after ONNX export; skip the .asrmodel step
```

### Package an already-exported directory

If the ONNX files are already in the cache from a previous run:

**Windows:**
```powershell
python package_model.py "$env:USERPROFILE\.cache\espnet_onnx\YuanyuanZhang\EnglishGigaspeechConformerFBank_M01" EnglishGigaspeechConformerFBank_M01
```

**macOS / Linux:**
```sh
python package_model.py ~/.cache/espnet_onnx/YuanyuanZhang/EnglishGigaspeechConformerFBank_M01 \
    EnglishGigaspeechConformerFBank_M01
```

The first argument is the export directory (must contain a `full/` subdirectory with the ONNX files).
The second argument is the model name written into the bundle.

`vocab.txt` is derived automatically from the vocabulary in `config.yaml` when it is not already
present in the export directory. Both the nested `token.list` layout (what `espnet_onnx` writes)
and the legacy top-level `token_list` layout are supported.

## The .asrmodel format

An `.asrmodel` file is a standard ZIP archive with a custom extension. Contents:

| Entry | Required | Description |
|-------|----------|-------------|
| `manifest.json` | yes | Format version, model name, file list + SHA-256 checksums |
| `encoder.onnx` | yes | Conformer encoder |
| `ctc.onnx` | yes | CTC output layer |
| `vocab.txt` | yes | Token vocabulary (one piece per line, index = token ID) |
| `decoder.onnx` | no | Transformer decoder; omitted for CTC-only models |

The app verifies every SHA-256 checksum in `manifest.json` before writing any file to storage.

## Running the tests

The venv must be activated first (tests import `package_model` which imports project dependencies).

```sh
# with pytest (already in requirements.txt):
python -m pytest test_package_model.py -v

# without pytest:
python -m unittest test_package_model -v
```
