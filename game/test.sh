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
	if ! "$GODOT_BIN" --headless --path "$GAME_DIR" --log-file "$log_file" --script "res://tests/$script_path" > "$log_file" 2>&1; then # source: required Godot headless test invocation.
		cat "$log_file"
		return 1
	fi
	if ! grep -q '^PASS:' "$log_file" || grep -Eq 'SCRIPT ERROR:|ERROR:|SHADER ERROR:' "$log_file"; then
		cat "$log_file"
		return 1
	fi
	cat "$log_file"
}

run_suite run_tests.gd
run_suite tests_engine_session.gd
run_suite test_world_interaction.gd
run_suite test_map_discovery.gd

run_suite test_engine_instruments.gd

run_suite test_train_journey.gd
run_suite test_city_trade.gd
run_suite test_playable_trip.gd

run_suite test_travel_world.gd
run_suite test_camera_scale.gd

run_suite test_pixel_field.gd
