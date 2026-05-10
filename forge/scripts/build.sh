#!/usr/bin/env bash
#configure and build the library with CMake
#usage (optimized build): ./scripts/build.sh [--release]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
BUILD_TYPE="Debug"

for arg in "$@"; do
    case $arg in
        --release) BUILD_TYPE="Release" ;;
        *)         echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

cmake -S "$ROOT_DIR" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
cmake --build "$BUILD_DIR" --parallel \
    "$(nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo 4)"

echo "done: $BUILD_DIR/libinference_engine.*"