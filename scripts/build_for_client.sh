#!/usr/bin/env bash
#
# Builds a macOS release of the app.
#
# Usage (from repo root):
#   ./scripts/build_for_client.sh
#
# The .app lands in build/macos/Build/Products/Release/.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"

echo "Refreshing dependencies..."
flutter pub get >/dev/null

echo "Building macOS release..."
flutter build macos --release

echo
echo "Build complete:"
echo "  $REPO/build/macos/Build/Products/Release/asr_application.app"
