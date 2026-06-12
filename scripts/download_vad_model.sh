#!/usr/bin/env bash
# Downloads the Silero VAD ONNX model to assets/silero_vad.onnx.
# Pinned to v6.2.1; the tensor names (input, sr, state, output, stateN) are
# part of the public API; bump the tag only after verifying the new model's
# tensor names match SileroVadService.
# Run once after cloning, or let the CI pipeline handle it automatically.
set -euo pipefail

DEST="assets/silero_vad.onnx"
PINNED_TAG="v6.2.1"
URL="https://github.com/snakers4/silero-vad/raw/${PINNED_TAG}/src/silero_vad/data/silero_vad.onnx"

if [ -f "$DEST" ]; then
  echo "silero_vad.onnx already present, skipping download."
  exit 0
fi

echo "Downloading Silero VAD model..."
if command -v curl >/dev/null 2>&1; then
  curl -fsSL -o "$DEST" "$URL"
elif command -v wget >/dev/null 2>&1; then
  wget -q -O "$DEST" "$URL"
else
  _tmp=$(mktemp /tmp/dl_XXXXXX.dart)
  cat > "$_tmp" << 'DART'
import 'dart:io';
void main(List<String> args) async {
  final client = HttpClient();
  final request = await client.getUrl(Uri.parse(args[1]));
  final response = await request.close();
  await response.pipe(File(args[0]).openWrite());
  client.close();
}
DART
  dart run "$_tmp" "$DEST" "$URL"
  rm -f "$_tmp"
fi
echo "Saved to $DEST ($(du -h "$DEST" | cut -f1))."
