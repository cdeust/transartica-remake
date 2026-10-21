#!/bin/sh
# SPDX-License-Identifier: MIT
set -eu
native_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$native_dir/../output/standalone-native-graphics-20261021/Transartica.app/Contents/MacOS/Transartica" "$@"
