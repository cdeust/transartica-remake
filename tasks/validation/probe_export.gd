extends SceneTree

# Execute using the exported binary, so this tests packaged resources and paths.
func _initialize():
	call_deferred("_run")


func _run():
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	await process_frame
	await process_frame
	if scene.world_data.cities.size() != 46:
		_fail("Packaged city data unavailable")
		return
	if not scene.session.reset() or not _check_engine(scene):
		return
	var path: String = scene._save_path()
	print("Runtime save path: " + path)
	if not path.is_absolute_path() or path.contains(".app/Contents"):
		_fail("Save path must be outside packaged resources and signed app")
		return
	var had_previous := FileAccess.file_exists(path)
	var previous := FileAccess.get_file_as_bytes(path) if had_previous else PackedByteArray()
	scene.session.advance(0.375)
	scene.session.paused = true
	scene.clock.set_elapsed(42.25)
	var expected_session: Dictionary = scene.session.snapshot()
	if not is_equal_approx(scene.session.accumulator, 0.375):
		_finish(path, had_previous, previous, "Residual update time was not retained")
		return
	var known_city: Dictionary = scene.world_data.cities[43]
	scene.world_view.discovery.visit_cell(Vector2i(known_city.x, known_city.y))
	scene.focus_city(43)
	scene.world_view.zoom = 1.75
	scene.world_view.offset = Vector2(125, -30)
	if not scene.save_view():
		_finish(path, had_previous, previous, "Exported runtime cannot save at " + path)
		return
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var expected_json: Variant = JSON.parse_string(JSON.stringify(expected_session))
	if not saved is Dictionary or not saved.has("session") or saved.session != expected_json:
		_finish(path, had_previous, previous, "Saved JSON omitted engine, pause, or residual state")
		return
	scene.queue_free()
	await process_frame
	var restarted = load("res://main.tscn").instantiate()
	root.add_child(restarted)
	restarted.set_process(false)
	await process_frame
	await process_frame
	var restored: bool = restarted.world_view.selected_city == 43
	restored = restored and is_equal_approx(restarted.world_view.zoom, 1.75)
	restored = restored and restarted.world_view.offset.is_equal_approx(Vector2(125, -30))
	restored = restored and restarted.session.snapshot() == expected_session
	restored = restored and is_equal_approx(restarted.clock.elapsed_seconds, 42.25)
	_finish(path, had_previous, previous, "" if restored else "Packaged restart lost chart, engine, pause, residual, or clock")


func _finish(path: String, had_previous: bool, previous: PackedByteArray, error: String):
	if not _restore_fixture(path, had_previous, previous):
		_fail("Could not restore the pre-existing save fixture at " + path)
		return
	if not error.is_empty():
		_fail(error)
		return
	print("PASS: packaged cities, locomotive rules, chart and full JSON session survive restart; path=" + path)
	quit(0)


func _restore_fixture(path: String, had_previous: bool, previous: PackedByteArray) -> bool:
	if not had_previous:
		return DirAccess.remove_absolute(path) == OK
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(previous)
	file.close()
	return true


func _fail(message: String):
	push_error(message)
	quit(1)


func _check_engine(scene) -> bool:
	var engine = scene.engine
	engine.cycle_lignite()
	engine.cycle_anthracite()
	engine.set_regulator(300)
	for cycle in 10:
		engine.step_cycle()
	if engine.lignite != 1990 or engine.anthracite != 490 or engine.speed != 15:
		_fail("Packaged engine consumption or acceleration mismatch")
		return false
	if engine.heat != 374 or engine.pressure_reserve != 2400:
		_fail("Packaged boiler state mismatch")
		return false
	engine.toggle_brake()
	engine.step_cycle()
	if engine.speed != 0 or engine.regulator != 300:
		_fail("Packaged brake mismatch")
		return false
	print("PASS: packaged locomotive heat, consumption, acceleration and brake")
	return true
