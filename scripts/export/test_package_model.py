"""
Unit tests for package_model.py.

Run with:  python -m pytest test_package_model.py  (from scripts/export/)
  or:      python -m unittest test_package_model   (no extra deps needed)
"""

import hashlib
import json
import unittest
import zipfile
from pathlib import Path
import tempfile
import os

from package_model import (
    package_model,
    resolve_vocab,
    sha256_file,
    detect_vocab_metadata,
    FORMAT_VERSION,
    EXTENSION,
)


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _write(path: Path, content: bytes) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)
    return path


def _make_export_dir(tmp: Path, include_decoder: bool = True, include_vocab: bool = True) -> Path:
    """Create a minimal ESPnet ONNX export directory structure."""
    full = tmp / "full"
    full.mkdir(parents=True)

    _write(full / "default_encoder.onnx", b"fake encoder " + bytes(range(64)))
    _write(full / "ctc.onnx", b"fake ctc " + bytes(range(64)))
    if include_decoder:
        _write(full / "xformer_decoder.onnx", b"fake decoder " + bytes(range(64)))
    if include_vocab:
        _write(tmp / "vocab.txt", b"<blank>\n<unk>\n\xe2\x96\x81hello\n\xe2\x96\x81world\n")

    return tmp


def _make_export_dir_with_config(tmp: Path, token_list=None) -> Path:
    """Create an export dir that has config.yaml but no vocab.txt."""
    try:
        import yaml
    except ImportError:
        raise unittest.SkipTest("PyYAML not installed")

    full = tmp / "full"
    full.mkdir(parents=True)
    _write(full / "default_encoder.onnx", b"encoder bytes")
    _write(full / "ctc.onnx", b"ctc bytes")

    tokens = token_list or ["<blank>", "<unk>", "▁hello", "▁world"]
    config = {"token_list": tokens, "encoder": {}, "ctc": {}}
    (tmp / "config.yaml").write_text(yaml.dump(config), encoding="utf-8")

    return tmp


class TestPackageModel(unittest.TestCase):

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    # ── happy path ────────────────────────────────────────────────────────────

    def test_creates_asrmodel_file(self):
        export_dir = _make_export_dir(self.tmp / "export")
        output = self.tmp / "MyModel.asrmodel"

        package_model(export_dir, "MyModel", output)

        self.assertTrue(output.exists(), "Output file was not created")
        self.assertTrue(zipfile.is_zipfile(output), "Output is not a valid ZIP")

    def test_output_has_correct_extension(self):
        export_dir = _make_export_dir(self.tmp / "export")
        output = self.tmp / "MyModel.asrmodel"

        package_model(export_dir, "MyModel", output)

        self.assertTrue(str(output).endswith(EXTENSION))

    def test_manifest_format_version(self):
        export_dir = _make_export_dir(self.tmp / "export")
        output = self.tmp / "out.asrmodel"
        package_model(export_dir, "M", output)

        with zipfile.ZipFile(output) as zf:
            manifest = json.loads(zf.read("manifest.json"))

        self.assertEqual(manifest["format_version"], FORMAT_VERSION)

    def test_manifest_model_name(self):
        export_dir = _make_export_dir(self.tmp / "export")
        output = self.tmp / "out.asrmodel"
        package_model(export_dir, "SpecialModel", output)

        with zipfile.ZipFile(output) as zf:
            manifest = json.loads(zf.read("manifest.json"))

        self.assertEqual(manifest["model_name"], "SpecialModel")

    def test_required_files_present_in_archive(self):
        export_dir = _make_export_dir(self.tmp / "export", include_decoder=False)
        output = self.tmp / "out.asrmodel"
        package_model(export_dir, "M", output)

        with zipfile.ZipFile(output) as zf:
            names = set(zf.namelist())

        self.assertIn("manifest.json", names)
        self.assertIn("encoder.onnx", names)
        self.assertIn("ctc.onnx", names)
        self.assertIn("vocab.txt", names)

    def test_decoder_included_when_present(self):
        export_dir = _make_export_dir(self.tmp / "export", include_decoder=True)
        output = self.tmp / "out.asrmodel"
        package_model(export_dir, "M", output)

        with zipfile.ZipFile(output) as zf:
            names = set(zf.namelist())
            manifest = json.loads(zf.read("manifest.json"))

        self.assertIn("decoder.onnx", names)
        self.assertTrue(manifest["has_decoder"])
        self.assertIn("decoder.onnx", manifest["files"])

    def test_decoder_absent_when_not_present(self):
        export_dir = _make_export_dir(self.tmp / "export", include_decoder=False)
        output = self.tmp / "out.asrmodel"
        package_model(export_dir, "M", output)

        with zipfile.ZipFile(output) as zf:
            names = set(zf.namelist())
            manifest = json.loads(zf.read("manifest.json"))

        self.assertNotIn("decoder.onnx", names)
        self.assertFalse(manifest["has_decoder"])

    def test_checksums_match_archive_contents(self):
        export_dir = _make_export_dir(self.tmp / "export")
        output = self.tmp / "out.asrmodel"
        package_model(export_dir, "M", output)

        with zipfile.ZipFile(output) as zf:
            manifest = json.loads(zf.read("manifest.json"))
            for filename, info in manifest["files"].items():
                actual = _sha256_bytes(zf.read(filename))
                self.assertEqual(
                    actual,
                    info["sha256"],
                    f"Checksum mismatch for {filename}",
                )

    def test_encoder_content_preserved(self):
        """File bytes in the archive must match the source files byte-for-byte."""
        export_dir = _make_export_dir(self.tmp / "export")
        original_encoder = (export_dir / "full" / "default_encoder.onnx").read_bytes()
        output = self.tmp / "out.asrmodel"
        package_model(export_dir, "M", output)

        with zipfile.ZipFile(output) as zf:
            archived = zf.read("encoder.onnx")

        self.assertEqual(archived, original_encoder)

    # ── vocab.txt auto-generation ─────────────────────────────────────────────

    def test_vocab_generated_from_config_yaml_when_missing(self):
        tokens = ["<blank>", "<unk>", "▁cat", "▁sat"]
        export_dir = _make_export_dir_with_config(self.tmp / "export", token_list=tokens)
        output = self.tmp / "out.asrmodel"
        package_model(export_dir, "M", output)

        with zipfile.ZipFile(output) as zf:
            vocab_text = zf.read("vocab.txt").decode("utf-8")

        lines = [l for l in vocab_text.split("\n") if l]
        self.assertEqual(lines, tokens)

    def test_existing_vocab_txt_takes_priority_over_config(self):
        try:
            import yaml
        except ImportError:
            self.skipTest("PyYAML not installed")

        export_dir = _make_export_dir_with_config(self.tmp / "export", token_list=["from_config"])
        # Write a vocab.txt that disagrees with config.yaml
        (export_dir / "vocab.txt").write_text("from_file\n", encoding="utf-8")
        output = self.tmp / "out.asrmodel"
        package_model(export_dir, "M", output)

        with zipfile.ZipFile(output) as zf:
            vocab_text = zf.read("vocab.txt").decode("utf-8")

        self.assertIn("from_file", vocab_text)
        self.assertNotIn("from_config", vocab_text)

    # ── error cases ───────────────────────────────────────────────────────────

    def test_raises_when_encoder_missing(self):
        export_dir = _make_export_dir(self.tmp / "export")
        (export_dir / "full" / "default_encoder.onnx").unlink()
        output = self.tmp / "out.asrmodel"

        with self.assertRaises(FileNotFoundError):
            package_model(export_dir, "M", output)

    def test_raises_when_ctc_missing(self):
        export_dir = _make_export_dir(self.tmp / "export")
        (export_dir / "full" / "ctc.onnx").unlink()
        output = self.tmp / "out.asrmodel"

        with self.assertRaises(FileNotFoundError):
            package_model(export_dir, "M", output)

    def test_raises_when_no_vocab_and_no_config(self):
        export_dir = _make_export_dir(self.tmp / "export", include_vocab=False)
        output = self.tmp / "out.asrmodel"

        with self.assertRaises(FileNotFoundError):
            package_model(export_dir, "M", output)


class TestVocabMetadata(unittest.TestCase):
    """Special-token detection that drives the manifest "vocab" block."""

    # A gigaspeech-style vocab: blank=0, unk=1, sos/eos last, no fillers.
    GIGASPEECH = ["<blank>", "<unk>"] + ["▁tok%d" % i for i in range(4996)] + ["<sos/eos>"]
    # A Dutch-CGN-style vocab: same shape plus three bracketed filler tokens.
    DUTCH = (
        ["<blank>", "<unk>", "[FIL]", "[LAUGH]", "[UNK]"]
        + ["▁tok%d" % i for i in range(4994)]
        + ["<sos/eos>"]
    )

    def test_gigaspeech_ids(self):
        meta = detect_vocab_metadata(self.GIGASPEECH)
        self.assertEqual(meta["blank_id"], 0)
        self.assertEqual(meta["unk_id"], 1)
        self.assertEqual(meta["sos_eos_id"], len(self.GIGASPEECH) - 1)
        # Only the blank is an extra suppressed id; unk/sos/eos are excluded.
        self.assertEqual(meta["suppressed_ids"], [0])
        self.assertEqual(meta["word_boundary_marker"], "▁")

    def test_dutch_suppresses_filler_tokens(self):
        meta = detect_vocab_metadata(self.DUTCH)
        self.assertEqual(meta["blank_id"], 0)
        self.assertEqual(meta["unk_id"], 1)
        self.assertEqual(meta["sos_eos_id"], len(self.DUTCH) - 1)
        # blank + the three bracketed fillers, but not unk/sos/eos.
        self.assertEqual(meta["suppressed_ids"], [0, 2, 3, 4])

    def test_overrides_take_precedence(self):
        meta = detect_vocab_metadata(
            self.DUTCH,
            {"sos_eos_id": 4242, "suppressed_ids": [0, 9]},
        )
        self.assertEqual(meta["sos_eos_id"], 4242)
        self.assertEqual(meta["suppressed_ids"], [0, 9])
        # Unspecified fields still come from detection.
        self.assertEqual(meta["blank_id"], 0)

    def test_none_overrides_are_ignored(self):
        meta = detect_vocab_metadata(self.GIGASPEECH, {"blank_id": None})
        self.assertEqual(meta["blank_id"], 0)

    def test_manifest_includes_vocab_block(self):
        tmp = Path(tempfile.mkdtemp())
        full = tmp / "full"
        full.mkdir()
        _write(full / "default_encoder.onnx", b"enc")
        _write(full / "ctc.onnx", b"ctc")
        (tmp / "vocab.txt").write_text(
            "\n".join(["<blank>", "<unk>", "[FIL]", "▁hi", "<sos/eos>"]),
            encoding="utf-8",
        )
        output = tmp / "out.asrmodel"
        package_model(tmp, "M", output)

        with zipfile.ZipFile(output) as zf:
            manifest = json.loads(zf.read("manifest.json"))

        self.assertEqual(manifest["format_version"], "2")
        self.assertIn("vocab", manifest)
        self.assertEqual(manifest["vocab"]["blank_id"], 0)
        self.assertEqual(manifest["vocab"]["unk_id"], 1)
        self.assertEqual(manifest["vocab"]["sos_eos_id"], 4)
        self.assertEqual(manifest["vocab"]["suppressed_ids"], [0, 2])


class TestResolveVocab(unittest.TestCase):

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def test_finds_vocab_in_export_root(self):
        vocab = self.tmp / "vocab.txt"
        vocab.write_bytes(b"<blank>\n")
        result = resolve_vocab(self.tmp)
        self.assertEqual(result, vocab)

    def test_finds_vocab_in_full_subdir(self):
        full = self.tmp / "full"
        full.mkdir()
        vocab = full / "vocab.txt"
        vocab.write_bytes(b"<blank>\n")
        result = resolve_vocab(self.tmp)
        self.assertEqual(result, vocab)

    def test_prefers_root_vocab_over_full_subdir(self):
        root_vocab = self.tmp / "vocab.txt"
        root_vocab.write_bytes(b"root\n")
        full = self.tmp / "full"
        full.mkdir()
        (full / "vocab.txt").write_bytes(b"full\n")
        result = resolve_vocab(self.tmp)
        self.assertEqual(result, root_vocab)

"""
This test was fully written by AI but checked and read over.
"""

if __name__ == "__main__":
    unittest.main()
