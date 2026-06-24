#!/usr/bin/env bash
#
# Builds a MacOS release of the app on MacOS.
#
# Usage (from repo root):
#   ./scripts/build/build_for_macos.sh
#
# The .app lands in build/macos/Build/Products/Release/.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"

echo "Refreshing dependencies..."
flutter pub get >/dev/null

echo "Building assets..."
dart run flutter_launcher_icons >/dev/null

echo "Building macOS release..."
flutter build macos --release

echo
echo "Build complete:"
echo "  $REPO/build/macos/Build/Products/Release/DISC.app"
