extends SceneTree

const EngineState = preload("res://scripts/engine_state.gd")
const EngineSession = preload("res://scripts/engine_session.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_test_frame_independence(failures)
	_test_pause_and_fractional_time(failures)
	_test_snapshot_resume_and_validation(failures)
	_test_reset_and_event_stop(failures)
	if failures.is_empty():
		print("PASS: engine session frame independence, pause, residual time, restore, reset, and event stop")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_frame_independence(failures: Array[String]) -> void:
	var fine_engine = EngineState.new()
	var coarse_engine = EngineState.new()
	fine_engine.cycle_lignite()
	coarse_engine.cycle_lignite()
	var fine = EngineSession.new(fine_engine, 1.0)
	var coarse = EngineSession.new(coarse_engine, 1.0)
	var fine_ticks: Array[int] = []
	var coarse_ticks: Array[int] = []
	fine.cycle_completed.connect(func() -> void: fine_ticks.append(1))
	coarse.cycle_completed.connect(func() -> void: coarse_ticks.append(1))
	for frame in 600:
		fine.advance(1.0 / 60.0)
	for frame in 150:
		coarse.advance(1.0 / 15.0)
	_check(fine_engine.snapshot() == coarse_engine.snapshot(), "60 Hz and 15 Hz schedules produce equal state", failures)
	_check(fine_engine.cycles == 10, "ten seconds at the injected cadence produce ten updates", failures)
	_check(fine_ticks.size() == 10 and coarse_ticks.size() == 10, "cycle signal count follows simulation steps at both frame rates", failures)


func _test_pause_and_fractional_time(failures: Array[String]) -> void:
	var engine = EngineState.new()
	var session = EngineSession.new(engine, 1.0)
	var ticks: Array[int] = []
	session.cycle_completed.connect(func() -> void: ticks.append(1))
	session.advance(0.375)
	_check(engine.cycles == 0 and is_equal_approx(session.accumulator, 0.375), "sub-cycle time remains in the accumulator", failures)
	session.paused = true
	session.advance(4.0)
	_check(engine.cycles == 0 and is_equal_approx(session.accumulator, 0.375), "pause does not accrue elapsed time", failures)
	_check(ticks.is_empty(), "pause emits no simulation-cycle signal", failures)
	session.paused = false
	session.advance(0.625)
	_check(engine.cycles == 1 and is_zero_approx(session.accumulator), "residual time completes one update after resume", failures)
	_check(ticks.size() == 1, "resumed simulation emits exactly one cycle signal", failures)


func _test_snapshot_resume_and_validation(failures: Array[String]) -> void:
	var source_engine = EngineState.new()
	source_engine.cycle_lignite()
	source_engine.set_regulator(175)
	var source = EngineSession.new(source_engine, 0.5)
	source.advance(0.25)
	source.paused = true
	var saved: Dictionary = source.snapshot()
	var resumed_engine = EngineState.new()
	var resumed = EngineSession.new(resumed_engine, 3.0)
	_check(resumed.restore(saved), "valid snapshot restores", failures)
	_check(resumed.snapshot() == saved, "restore preserves engine, cadence, pause, and residual", failures)
	_check(resumed_engine.snapshot() == source_engine.snapshot(), "engine fields restore exactly", failures)
	_test_json_roundtrip(saved, failures)
	var before: Dictionary = resumed.snapshot()
	var invalid: Dictionary = saved.duplicate(true)
	invalid.engine.regulator = 301
	_check(not resumed.restore(invalid), "out-of-range regulator is refused", failures)
	_check(resumed.snapshot() == before, "invalid restore leaves session unchanged", failures)
	invalid = saved.duplicate(true)
	invalid.accumulator = NAN
	_check(not resumed.restore(invalid), "non-finite residual is refused", failures)
	_check(resumed.snapshot() == before, "non-finite restore leaves session unchanged", failures)
	invalid = saved.duplicate(true)
	invalid.engine.train_mass = 0
	_check(not resumed.restore(invalid), "zero train mass is refused (divisor undefined)", failures)
	_check(resumed.snapshot() == before, "unsupported mass leaves session unchanged", failures)
	_check(not resumed_engine.restore({"lignite": -1}), "incomplete engine state is refused", failures)
	_check(resumed_engine.snapshot() == source_engine.snapshot(), "invalid engine restore is transactional", failures)
	var invalid_engine: Dictionary = source_engine.snapshot()
	invalid_engine.train_mass = 32768
	_check(not resumed_engine.restore(invalid_engine), "engine snapshot rejects mass beyond 16 bits", failures)
	_check(resumed_engine.snapshot() == source_engine.snapshot(), "unsupported engine mass is transactional", failures)


func _test_json_roundtrip(saved: Dictionary, failures: Array[String]) -> void:
	var encoded := JSON.stringify(saved)
	var decoded: Variant = JSON.parse_string(encoded)
	_check(decoded is Dictionary, "session snapshot survives JSON encoding", failures)
	if not decoded is Dictionary:
		return
	var engine = EngineState.new()
	var session = EngineSession.new(engine, 7.0)
	_check(session.restore(decoded), "JSON-decoded snapshot restores", failures)
	_check(session.snapshot() == saved, "JSON roundtrip preserves all saved session fields", failures)


func _test_reset_and_event_stop(failures: Array[String]) -> void:
	var reset_engine = EngineState.new()
	var initial: Dictionary = reset_engine.snapshot()
	var reset_session = EngineSession.new(reset_engine, 1.0)
	reset_engine.cycle_anthracite()
	reset_session.advance(1.5)
	reset_session.paused = true
	_check(reset_session.reset(), "reset succeeds", failures)
	_check(reset_engine.snapshot() == initial, "reset restores initial engine values", failures)
	_check(not reset_session.paused and is_zero_approx(reset_session.accumulator), "reset clears pause and residual", failures)
	var event_engine = EngineState.new()
	event_engine.heat = 5000
	event_engine.cycle_lignite()
	event_engine.cycle_lignite()
	var event_session = EngineSession.new(event_engine, 1.0)
	var event_ticks: Array[int] = []
	event_session.cycle_completed.connect(func() -> void: event_ticks.append(1))
	event_session.advance(5.0)
	_check(event_engine.event_pending and event_engine.event_message == "Boiler overload", "original overload event is raised", failures)
	_check(event_engine.cycles == 1, "event suspends the remaining accumulated updates", failures)
	_check(event_ticks.size() == 1, "event-producing update emits its completed-cycle signal", failures)
	_check(is_zero_approx(event_session.accumulator), "event does not leave a catch-up backlog", failures)
	event_session.advance(10.0)
	_check(event_engine.cycles == 1, "pending event prevents further updates", failures)
	_check(event_ticks.size() == 1, "pending event emits no later-cycle signal", failures)


func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
