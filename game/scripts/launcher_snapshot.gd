extends RefCounted

# MIT. Pure staged validation; no wagon debit or enemy removal here.
const Model = preload("res://scripts/launcher_model.gd")
const Geometry = preload("res://scripts/launcher_geometry.gd")
const Enemies = preload("res://scripts/enemy_trains.gd")


static func integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and value == floor(value)


static func validate(value: Variant, wagons, enemies, origin: Vector2i) -> bool:
	if not value is Dictionary or value.keys().size() != 5 or value.get("version") != 1:
		return false
	for key in ["active","visible","paused"]:
		if not value.get(key) is bool:
			return false
	if not value.get("state") is Dictionary:
		return false
	if not value.active:
		return value.state.is_empty() and not value.visible and not value.paused
	if not wagons.wagons.any(func(w): return w[0] == 13) or not wagons.wagons.any(func(w): return w[2] == 2 and w[3] > 0):
		return false
	return _state(value.state,enemies,origin)


static func _state(state: Dictionary, enemies, origin: Vector2i) -> bool:
	var initial := Model.new().snapshot()
	if state.keys().size() != initial.keys().size():
		return false
	for key in initial:
		if not state.has(key):
			return false
	for key in ["bearing","cursor","ascent","ascent_step","scroll_left","status"]:
		if not integer(state[key]):
			return false
	if state.bearing < 0 or state.bearing > 31 or not state.removed is bool:
		return false
	if not state.digits is Array or state.digits.size() != 4:
		return false
	for digit in state.digits:
		if not integer(digit) or digit < 0 or digit > 9:
			return false
	if not typeof(state.accumulator) in [TYPE_INT,TYPE_FLOAT] or not is_finite(state.accumulator) or state.accumulator < 0 or state.accumulator >= 3.0/50.0:
		return false
	var model := Model.new()
	model.bearing = int(state.bearing)
	model.digits = normalized(state.digits)
	if model.distance() < 50 or not state.geometry is Dictionary:
		return false
	if state.geometry.is_empty():
		return _aim(state,initial)
	return _flight(state,model,enemies,origin)


static func _aim(state: Dictionary, initial: Dictionary) -> bool:
	if not state.phase in ["aim","armed","arming","disarming"]:
		return false
	initial.bearing = state.bearing
	initial.digits = state.digits
	initial.phase = state.phase
	initial.cursor = state.cursor
	initial.accumulator = state.accumulator
	if state.cursor < 0 or state.cursor >= 5 or (state.phase in ["aim","armed"] and state.cursor != 0):
		return false
	return normalized(state) == normalized(initial)


static func _flight(state: Dictionary, model, enemies, origin: Vector2i) -> bool:
	var geometry: Dictionary = state.geometry
	if not integer(geometry.get("target")) or geometry.target < -1 or geometry.target >= 30:
		return false
	var staged := Enemies.new()
	if not staged.restore(enemies.snapshot()):
		return false
	if geometry.target >= 0:
		if not geometry.get("record") is Array or geometry.record.size() != 8:
			return false
		var target: int = geometry.target
		if state.removed:
			if staged.slots[target] != [2,0,0,0,0,0,0,0]:
				return false
		elif normalized(staged.slots[target]) != normalized(geometry.record):
			return false
		staged.slots[target] = normalized(geometry.record)
		# Removed targets need their historical record validated before geometry reads.
		if not staged.restore(staged.snapshot()):
			return false
	var expected := Geometry.calculate(model.bearing,model.distance(),origin,staged)
	if expected.is_empty() or normalized(expected) != normalized(geometry):
		return false
	model.phase = "armed"
	model.action(108,origin,staged)
	# Replay the finite source continuation, rather than trusting cursor/flags.
	while true:
		model.removed = model.phase in ["impact","report"] and expected.target >= 0
		var candidate: Dictionary = model.snapshot()
		candidate.accumulator = state.accumulator
		if normalized(candidate) == normalized(state):
			return true
		if model.phase == "report":
			return false
		model.step()
	return false


static func normalized(value: Variant) -> Variant:
	if value is Array:
		var result := []
		for item in value:
			result.append(normalized(item))
		return result
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = normalized(value[key])
		return result
	if integer(value):
		return int(value)
	return value
