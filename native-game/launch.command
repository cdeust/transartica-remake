#!/bin/sh
# SPDX-License-Identifier: MIT
set -eu
native_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
build_dir=${TRANSARTICA_BUILD_DIR:-"$native_dir/../build/native"}
if [ ! -x "$build_dir/Transartica" ]; then
    echo "Build the native game first: cmake -S native-game -B build/native && cmake --build build/native --parallel 1" >&2
    echo "For a different build directory, set TRANSARTICA_BUILD_DIR." >&2
    exit 1
fi
exec "$build_dir/Transartica" "$@"
