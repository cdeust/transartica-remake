extends RefCounted
class_name EngineSession

const EngineStateScript = preload("res://scripts/engine_state.gd")

var engine
var paused := false
var seconds_per_cycle: float
var accumulator := 0.0
var _initial_engine_state: Dictionary

signal cycle_completed


func _init(engine_state, provisional_seconds_per_cycle: float) -> void:
	assert(engine_state != null, "EngineSession requires an EngineState")
	assert(is_finite(provisional_seconds_per_cycle) and provisional_seconds_per_cycle > 0.0, "A positive provisional cadence is required")
	engine = engine_state
	seconds_per_cycle = provisional_seconds_per_cycle
	_initial_engine_state = engine.snapshot()


func advance(delta: float) -> void:
	if paused or engine.event_pending or not is_finite(delta) or delta <= 0.0:
		return
	accumulator += delta
	while accumulator >= seconds_per_cycle or (accumulator > 0.0 and is_equal_approx(accumulator, seconds_per_cycle)):
		accumulator = maxf(0.0, accumulator - seconds_per_cycle)
		engine.step_cycle()
		cycle_completed.emit()
		if engine.event_pending:
			accumulator = 0.0
			return


func reset() -> bool:
	if not engine.restore(_initial_engine_state):
		return false
	paused = false
	accumulator = 0.0
	return true


func snapshot() -> Dictionary:
	return {
		"engine": engine.snapshot(),
		"seconds_per_cycle": seconds_per_cycle,
		"accumulator": accumulator,
		"paused": paused,
	}


func restore(data: Variant) -> bool:
	if not _session_values_valid(data):
		return false
	var candidate = EngineStateScript.new()
	if not candidate.restore(data.engine):
		return false
	if not engine.restore(data.engine):
		return false
	seconds_per_cycle = float(data.seconds_per_cycle)
	accumulator = float(data.accumulator)
	paused = data.paused
	return true


func _session_values_valid(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for key in ["engine", "seconds_per_cycle", "accumulator", "paused"]:
		if not data.has(key):
			return false
	if typeof(data.paused) != TYPE_BOOL:
		return false
	if not _is_positive_finite(data.seconds_per_cycle):
		return false
	if not _is_nonnegative_finite(data.accumulator):
		return false
	return float(data.accumulator) < float(data.seconds_per_cycle)


func _is_positive_finite(value: Variant) -> bool:
	return _is_finite_number(value) and float(value) > 0.0


func _is_nonnegative_finite(value: Variant) -> bool:
	return _is_finite_number(value) and float(value) >= 0.0


func _is_finite_number(value: Variant) -> bool:
	var type := typeof(value)
	return (type == TYPE_INT or type == TYPE_FLOAT) and is_finite(float(value))
