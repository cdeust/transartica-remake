extends SceneTree

const Discovery = preload("res://scripts/map_discovery.gd")
const WorldData = preload("res://scripts/world_data.gd")
const WorldView = preload("res://scripts/world_view.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_test_observe_cell(failures)
	var discovery = Discovery.new()
	_check(discovery.current_position == Vector2i(12, 62), "starts on the source-verified TABLE cell", failures)
	_check(discovery.is_discovered(11, 61) and discovery.is_discovered(13, 63), "reveals immediate neighboring cells", failures)
	_check(not discovery.is_discovered(14, 62), "does not reveal beyond the chosen local preview radius", failures)
	var before := discovery.snapshot()
	_check(discovery.visit_cell(Vector2i(20, 20)), "valid visit updates current position", failures)
	_check(discovery.is_discovered(19, 19) and discovery.is_discovered(21, 21), "new visit expands persistent discovery", failures)
	_check(discovery.is_discovered(11, 61), "previous discovery remains revealed", failures)
	_check(not discovery.visit_cell(Vector2i(-1, 20)), "rejects out-of-bounds visit", failures)
	_check(discovery.snapshot().current_position == [20, 20], "invalid visit leaves current position unchanged", failures)
	var restored = Discovery.new()
	var encoded := JSON.stringify(discovery.snapshot())
	_check(restored.restore(JSON.parse_string(encoded)), "restores JSON discovery snapshot", failures)
	_check(restored.snapshot() == discovery.snapshot(), "snapshot round-trip preserves visited cells", failures)
	var parsed_number_state := {"version": 1.0, "current_position": [20.0, 20.0], "discovered_cells": [[1.0, 1.0]]}
	_check(restored.restore(parsed_number_state), "accepts integral JSON numbers represented as floats", failures)
	_check(not restored.restore({"version": 1, "current_position": [20.5, 20], "discovered_cells": []}), "rejects fractional coordinates", failures)
	var saved_before_invalid: Dictionary = restored.snapshot()
	_check(not restored.restore({"version": 1, "current_position": [160, 20], "discovered_cells": []}), "rejects invalid snapshot coordinates", failures)
	_check(restored.snapshot() == saved_before_invalid, "invalid restore is atomic", failures)
	var data = WorldData.new()
	var root_path := ProjectSettings.globalize_path("res://").trim_suffix("/")
	_check(data.load_from_project(root_path), "loads map/city fixture", failures)
	if failures.is_empty():
		_test_camera_and_hidden_city(data, failures)
	if failures.is_empty():
		print("PASS: persistent map discovery, bounded visits, camera invariance, and hidden-city filtering")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_camera_and_hidden_city(data, failures: Array[String]) -> void:
	var view = WorldView.new()
	view.world_data = data
	view.size = Vector2(900, 600)
	_check(view.discovery_enabled, "fog-of-war is enabled in the authorized preview", failures)
	var discovery_before: Dictionary = view.discovery.snapshot()
	view.discovery_enabled = false
	_check(view._city_is_visible(data.cities[0]), "research mode can show the full map", failures)
	view.discovery_enabled = true
	view.fit_world()
	view.pan_by(Vector2(40, 25))
	view.zoom_by(1.5, Vector2(200, 100))
	_check(view.discovery.snapshot() == discovery_before, "fit, pan, and zoom do not reveal cells", failures)
	var city: Dictionary = data.cities[0]
	_check(not view._city_is_visible(city), "remote city is hidden initially", failures)
	_check(view._city_at(view._city_screen_point(city)) == -1, "hidden city cannot be hit-selected", failures)
	view.focus_city(0)
	_check(view.selected_city == -1, "hidden city cannot be focused", failures)
	_check(view.visit_cell(Vector2i(city.x, city.y)), "visiting city coordinate succeeds", failures)
	_check(view._city_is_visible(city), "city becomes visible only after visit", failures)
	_check(view._city_at(view._city_screen_point(city)) == 0, "revealed city becomes hit-selectable", failures)
	view.free()


func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _test_observe_cell(failures: Array[String]) -> void:
	var discovery = Discovery.new()
	var marker: Vector2i = discovery.current_position
	_check(not discovery.is_discovered(8,62), "tail area begins outside locomotive reveal radius", failures)
	_check(discovery.observe_cell(Vector2i(8,62)), "first wagon observation reports newly revealed cells", failures)
	_check(discovery.is_discovered(8,62) and discovery.is_discovered(7,61), "wagon observation reveals cell and configured neighbors", failures)
	_check(discovery.current_position == marker, "wagon observation does not move player marker", failures)
	_check(not discovery.is_discovered(5,62), "distant track remains hidden after wagon observation", failures)
	var observed: Dictionary = discovery.snapshot()
	_check(not discovery.observe_cell(Vector2i(8,62)), "repeated observation reports no change", failures)
	_check(discovery.snapshot() == observed, "repeat observation is idempotent", failures)
	_check(not discovery.observe_cell(Vector2i(-1,62)) and discovery.snapshot() == observed, "invalid observation rejected without state mutation", failures)
	var restored = Discovery.new()
	_check(restored.restore(JSON.parse_string(JSON.stringify(observed))), "wagon discovery survives JSON restore", failures)
	_check(restored.current_position == marker and restored.is_discovered(8,62), "restored fog keeps player marker and tail discovery", failures)
