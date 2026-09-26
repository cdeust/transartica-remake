extends SceneTree

const EngineState = preload("res://scripts/engine_state.gd")
const EngineSession = preload("res://scripts/engine_session.gd")
const RoomControls = preload("res://scripts/engine_room_controls.gd")
const Instruments = preload("res://scripts/engine_instruments.gd")

var requested: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var engine = EngineState.new()
	engine.pressure_reserve = 1234
	engine.speed = 42
	engine.temperature = 318
	engine.heat = 3100
	engine.lignite_rate = 1
	engine.anthracite_rate = 2
	var session = EngineSession.new(engine, 0.5)
	var controls = RoomControls.new()
	controls.session = session
	root.add_child(controls)
	controls.requested.connect(_capture_request)
	controls.activate("gauges")
	_check(controls.show_instruments and requested == ["instruments"], "cab gauge click requests full-screen instruments", failures)
	_check(not session.paused, "opening instruments leaves simulation running", failures)
	session.advance(0.5)
	_check(engine.cycles == 1 and not session.paused, "engine session continues while instruments are active", failures)
	_test_readouts(engine, session, failures)
	_test_manual_controls(engine, session, failures)
	controls.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: live instrument readouts, regulator, full-screen routing, and running session")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_readouts(engine, session, failures: Array[String]) -> void:
	var view = Instruments.new()
	view.size = Vector2(1600, 1000)
	view.bind_session(session)
	root.add_child(view)
	var values: Dictionary = view.instrument_values()
	_check(values.boiler_pressure_raw == engine.heat, "boiler pressure remains raw", failures)
	_check(values.speed_kmh == engine.speed, "speed readout uses live engine value", failures)
	_check(values.piston_pressure == engine.pressure_reserve / 200 and values.piston_pressure_modelled, "TRAIN numeric reserve scale is used", failures)
	_check(values.temperature_raw == engine.temperature, "temperature readout uses live engine value", failures)
	_check(values.heat_raw == engine.heat and values.heat_event_if_above == 5000, "heat risk exposes original overload comparison", failures)
	_check(values.lignite_rate == engine.lignite_rate and values.anthracite_rate == engine.anthracite_rate, "both live fuel rates are exposed", failures)
	view.refresh()
	var previous: Array = view._last_state.duplicate()
	view.refresh()
	_check(view._last_state == previous, "unchanged readouts do not invalidate state", failures)
	view.queue_free()


func _test_manual_controls(engine, session, failures: Array[String]) -> void:
	var view = Instruments.new()
	view.size = Vector2(1600, 1000)
	view.bind_session(session)
	root.add_child(view)
	view.requested.connect(_capture_request)
	view._handle_click(view.REGULATOR_AREA.position + Vector2(25, 50))
	_check(engine.regulator == 0, "manual regulator left endpoint sets minimum", failures)
	view._handle_click(Vector2(view.REGULATOR_MAX_X, view.REGULATOR_AREA.position.y + 50))
	_check(engine.regulator == 300, "manual regulator right endpoint sets maximum", failures)
	view._handle_click(view.BACK_AREA.position + Vector2(5, 5))
	_check(requested == ["instruments", "room"], "manual exit returns to engine room", failures)
	_check(not session.paused, "manual controls never pause session", failures)
	view.queue_free()


func _capture_request(action: String) -> void:
	requested.append(action)


func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
