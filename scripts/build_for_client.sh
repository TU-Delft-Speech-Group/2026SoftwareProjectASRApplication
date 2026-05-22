#!/usr/bin/env bash
#
# Builds a macOS release that bundles only the Gigaspeech model.
#
# How it works:
#   1. Backs up pubspec.yaml.
#   2. Strips the lines between DEV_ONLY_ASSETS_BEGIN and DEV_ONLY_ASSETS_END
#      markers so the Librispeech assets aren't bundled.
#   3. Runs flutter pub get + flutter build macos --release.
#   4. Restores pubspec.yaml (always, even on failure).
#
# Usage (from repo root):
#   ./scripts/build_for_client.sh
#
# The .app lands in build/macos/Build/Products/Release/.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PUBSPEC="$REPO/pubspec.yaml"
BACKUP="$(mktemp -t pubspec.client-build)"

cp "$PUBSPEC" "$BACKUP"
trap 'mv "$BACKUP" "$PUBSPEC"; echo "pubspec.yaml restored."' EXIT

echo "Stripping dev-only assets from pubspec.yaml..."
# Delete every line from the BEGIN marker through the END marker (inclusive).
# Works with BSD sed (macOS) — uses /pattern/,/pattern/d range delete.
sed -i '' '/# >>> DEV_ONLY_ASSETS_BEGIN/,/# <<< DEV_ONLY_ASSETS_END/d' "$PUBSPEC"

echo "Refreshing dependencies..."
flutter pub get >/dev/null

echo "Building macOS release..."
flutter build macos --release

echo
echo "Build complete:"
echo "  $REPO/build/macos/Build/Products/Release/asr_application.app"
