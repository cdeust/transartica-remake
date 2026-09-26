#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GODOT_BIN="$PROJECT_DIR/../.toolchain/Godot.app/Contents/MacOS/Godot"
mkdir -p "$PROJECT_DIR/../.cache"
exec "$GODOT_BIN" --path "$PROJECT_DIR" --log-file "$PROJECT_DIR/../.cache/game.log" "$@"
