#!/usr/bin/env bash
#removes the CMake build directory
#usage : ./scripts/clean.sh
#build/ is deleted, so run build.sh to rebuild

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/build"

if [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
    echo "done: $BUILD_DIR removed"
else
    echo "nothing to clean"
fi