extends SceneTree

const EngineModel = preload("res://scripts/engine_state.gd")
const Clock = preload("res://scripts/survey_clock.gd")
const WorldData = preload("res://scripts/world_data.gd")
const WorldView = preload("res://scripts/world_view.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failures: Array[String] = []
	for path in ["res://scripts/main.gd", "res://scripts/world_view.gd", "res://scripts/world_data.gd", "res://scripts/cab_vignette.gd"]:
		var script = load(path)
		_check(script != null and script.can_instantiate(), "script compiles: " + path, failures)
	if not failures.is_empty():
		_report_failures(failures)
		return
	_test_engine(failures)
	_test_world_data(failures)
	_test_clock_schedule_independence(failures)
	_test_view_controls(failures)
	await _test_application_view_persistence(failures)
	if failures.is_empty():
		print("PASS: original locomotive rule vectors, world data, city selection, pan/zoom, and render-independent clock")
		quit(0)
	else:
		_report_failures(failures)


func _report_failures(failures: Array[String]) -> void:
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_world_data(failures: Array[String]) -> void:
	var data = WorldData.new()
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	_check(data.load_from_project(root), "loads local reference files", failures)
	_check(data.map_bytes.size() == 11680, "keeps the original map byte count", failures)
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(data.map_bytes)
	var digest := hasher.finish().hex_encode()
	_check(digest == "8e1067619b254d57717348fefedc1b5013eb1d7ba23200a815e36f9b856d811a", "keeps exact original map bytes", failures)
	var sample_index := 12 * WorldData.MAP_HEIGHT + 20
	_check(data.map_code(12, 20) == data.map_bytes[sample_index], "uses column-major map placement", failures)
	_check(data.map_code(160, 0) == -1, "rejects out-of-map coordinates", failures)
	_check(data.cities.size() == 46, "loads all decoded city records", failures)
	for city in data.cities:
		_check(city.x >= 0 and city.x < 160 and city.y >= 0 and city.y < 73, "city coordinate fits original map", failures)


func _test_clock_schedule_independence(failures: Array[String]) -> void:
	var fine = Clock.new()
	var coarse = Clock.new()
	for frame in 120:
		fine.advance(1.0 / 60.0)
	for frame in 30:
		coarse.advance(1.0 / 15.0)
	_check(is_equal_approx(fine.elapsed_seconds, coarse.elapsed_seconds), "equal elapsed time across 60 Hz and 15 Hz schedules", failures)
	fine.paused = true
	fine.advance(5.0)
	_check(is_equal_approx(fine.elapsed_seconds, 2.0), "paused clock does not advance", failures)


func _test_view_controls(failures: Array[String]) -> void:
	var view = WorldView.new()
	view.size = Vector2(1200, 700)
	view.fit_world()
	var original_offset: Vector2 = view.offset
	view.pan_by(Vector2(30, -20))
	_check(view.offset != original_offset, "pan changes map position", failures)
	var original_zoom: float = view.zoom
	view.zoom_by(1.2, Vector2(400, 300))
	_check(view.zoom > original_zoom, "zoom control changes map scale", failures)
	var original_pan: Vector2 = view.offset
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(90, 80)
	view._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(110, 95)
	view._gui_input(motion)
	_check(view.offset != original_pan, "mouse drag pans the map", failures)
	var data = WorldData.new()
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	data.load_from_project(root)
	view.world_data = data
	view.discovery.visit_cell(Vector2i(data.cities[0].x, data.cities[0].y))
	view.focus_city(0)
	_check(view.selected_city == 0, "city selection focuses a recorded location", failures)
	view.free()


func _test_application_view_persistence(failures: Array[String]) -> void:
	var temp_save := ProjectSettings.globalize_path("res://../.cache/game-startup-test.json")
	DirAccess.make_dir_recursive_absolute(temp_save.get_base_dir())
	var seed_file := FileAccess.open(temp_save, FileAccess.WRITE)
	seed_file.store_string(JSON.stringify({"discovery": preload("res://scripts/map_discovery.gd").new().snapshot(), "zoom": 1.6, "offset_x": 37.0, "offset_y": -22.0, "selected_city": -1, "elapsed_seconds": 77.0}))
	seed_file.close()
	var app = load("res://main.tscn").instantiate()
	app.save_path_override = temp_save
	root.add_child(app)
	await process_frame
	_check(app.world_data.cities.size() == 46, "application scene loads all city records", failures)
	_check(is_equal_approx(app.world_view.zoom, 1.6), "startup restore keeps saved zoom after layout", failures)
	_check(app.world_view.offset == Vector2(37.0, -22.0), "startup restore keeps saved map offset after layout", failures)
	_check(app.world_view.selected_city == -1, "startup restore keeps empty city selection", failures)
	_check(app.city_list.get_selected_items().is_empty(), "startup restore clears city-list selection", failures)
	_check(is_equal_approx(app.clock.elapsed_seconds, 77.0), "startup restore keeps saved clock", failures)
	var known_city: Dictionary = app.world_data.cities[3]
	app.world_view.discovery.visit_cell(Vector2i(known_city.x, known_city.y))
	app._filter_cities("")
	app.world_view.focus_city(3)
	app.clock.set_elapsed(123.0)
	_check(app.save_view(), "save action writes a local view", failures)
	app.world_view.focus_city(7)
	app.clock.set_elapsed(8.0)
	app._restore_view()
	_check(app.world_view.selected_city == 3, "restore returns to saved city", failures)
	_check(is_equal_approx(app.clock.elapsed_seconds, 123.0), "restore returns to saved clock", failures)
	app.world_view.selected_city = -1
	app.city_list.deselect_all()
	app.clock.set_elapsed(200.0)
	_check(app.save_view(), "save supports no selected city", failures)
	app.world_view.focus_city(7)
	app._restore_view()
	_check(app.world_view.selected_city == -1, "restore clears a later city selection", failures)
	_check(app.city_list.get_selected_items().is_empty(), "restore clears a later list selection", failures)
	DirAccess.remove_absolute(temp_save)
	app.queue_free()
	await process_frame


func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _test_engine(failures: Array[String]) -> void:
	# source: TABLE 0x6fa/0x701; TIME 0xea..0x1ed and 0x29d..0x300.
	var engine = EngineModel.new()
	_check(engine.lignite == 2000 and engine.anthracite == 500, "original starting coal stocks", failures)
	engine.cycle_lignite()
	engine.cycle_anthracite()
	engine.step_cycle()
	_check(engine.lignite == 1999 and engine.anthracite == 499, "one load consumes one of each stock", failures)
	_check(engine.heat == 39 and engine.pressure_reserve == 0, "first update: 40 heat minus one, below steam threshold", failures)
	engine.step_cycle()
	engine.step_cycle()
	_check(engine.heat == 116 and engine.pressure_reserve == 200, "third update crosses the original heat threshold", failures)
	engine.cycle_lignite()
	engine.cycle_lignite()
	_check(engine.lignite_rate == 0 and engine.anthracite_rate == 1, "stokers cycle independently", failures)
	engine.set_regulator(300)
	engine.pressure_reserve = 2000
	engine.step_cycle()
	_check(engine.speed == 5, "pressure permits original five-unit acceleration", failures)
	engine.toggle_brake()
	engine.step_cycle()
	_check(engine.speed == 0 and engine.regulator == 300 and engine.anthracite_rate == 1, "brake preserves regulator and stoking", failures)
	var braking = EngineModel.new()
	braking.speed = 100
	braking.regulator = 300
	braking.pressure_reserve = 2000
	braking.toggle_brake()
	var speeds: Array[int] = []
	for step in 25:
		braking.step_cycle()
		speeds.append(braking.speed)
	_check(speeds[0] == 95 and speeds[1] == 90, "service brake lowers speed by the original five-unit step", failures)
	_check(speeds[19] == 0 and speeds[24] == 0, "service brake reaches and holds zero after twenty cycles from 100", failures)
	var strictly_decreasing := true
	for index in range(1, 20):
		strictly_decreasing = strictly_decreasing and speeds[index] < speeds[index - 1]
	_check(strictly_decreasing, "service brake speed strictly decreases until stopped", failures)
	_check(braking.regulator == 300, "service brake overrides but preserves the regulator target", failures)
	braking.toggle_brake()
	braking.step_cycle()
	_check(braking.speed == 5, "releasing the brake resumes original acceleration toward the regulator", failures)
	engine.heat = 5000
	engine.step_cycle()
	_check(engine.event_pending and engine.event_message == "Boiler overload", "original overload threshold halts the test", failures)
	var rolling = EngineModel.new()
	rolling.speed = 300
	rolling.regulator = 300
	rolling.pressure_reserve = 2000
	rolling.step_cycle()
	_check(rolling.pressure_reserve == 1794, "six starting wagons consume floor(9300/45)=206 reserve at speed 300", failures)
	var stopped_cycles: int = engine.cycles
	engine.step_cycle()
	_check(engine.cycles == stopped_cycles, "unported event suspends further test cycles", failures)
