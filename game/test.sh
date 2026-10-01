#!/bin/sh
set -eu

GAME_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname -- "$GAME_DIR")
GODOT_BIN="$PROJECT_ROOT/.toolchain/Godot.app/Contents/MacOS/Godot"
mkdir -p "$PROJECT_ROOT/.cache"

run_suite() {
	script_path=$1
	# source: authored test runner convention, one log per independently run suite.
	log_name=$(basename "$script_path" .gd).log # source: independent logs keep each suite's failures attributable.
	log_file="$PROJECT_ROOT/.cache/$log_name"
	# Source: screenshot assertions require an actual renderer, not Godot's dummy
	# headless surface. The test explicitly declares this requirement.
	if grep -q '^# requires-native-renderer' "$GAME_DIR/tests/$script_path"; then
		set --
	else
		set -- --headless
	fi
	# Source: keep engine logging separate from shell output; two writers to the
	# same file can overwrite the script error needed for rejection.
	if ! "$GODOT_BIN" "$@" --path "$GAME_DIR" --log-file "$log_file.engine" --script "res://tests/$script_path" > "$log_file" 2>&1; then # source: Godot script runner invocation.
		cat "$log_file"
		return 1
	fi
	if ! grep -q '^PASS:' "$log_file" || grep -Eq 'SCRIPT ERROR:|ERROR:|SHADER ERROR:' "$log_file"; then
		cat "$log_file"
		return 1
	fi
	cat "$log_file"
}

# source: Godot imports are required before load() can read authored PNG assets.
# Complete test inventory: every SceneTree test script, excluding review captures.
"$GODOT_BIN" --headless --editor --path "$GAME_DIR" --log-file "$PROJECT_ROOT/.cache/test-import.log.engine" --import > "$PROJECT_ROOT/.cache/test-import.log" 2>&1
if grep -Eq 'SCRIPT ERROR:|ERROR:|SHADER ERROR:' "$PROJECT_ROOT/.cache/test-import.log"; then
	cat "$PROJECT_ROOT/.cache/test-import.log"
	exit 1
fi
run_suite run_tests.gd
for suite_path in "$GAME_DIR"/tests/test*.gd; do
	run_suite "$(basename "$suite_path")"
done
