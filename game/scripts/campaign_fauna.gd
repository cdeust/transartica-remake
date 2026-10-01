extends RefCounted

# MIT. TABLE0x56f..59e; TIME0x85f..8ed; YODA0x29dc..2af6.
const STARTS := [Vector2i(8,0), Vector2i(149,1), Vector2i(43,13), Vector2i(107,14), Vector2i(86,24), Vector2i(11,27), Vector2i(144,31), Vector2i(48,42), Vector2i(109,40), Vector2i(124,58), Vector2i(90,67)]
var initialized := false
var cell := Vector2i.ZERO
var heading := 6
var phase := 0
var counter := 0
var frozen := false
var history: Array[Vector2i] = []


func initialize(rng: RandomNumberGenerator) -> void:
	if not initialized:
		relocate(rng)


func relocate(rng: RandomNumberGenerator) -> void:
	cell = STARTS[rng.randi_range(0, 10)]
	heading = 6
	phase = 0
	counter = 0
	frozen = false
	initialized = true


func oslo() -> void:
	cell = Vector2i(126, 15) # SCENE4 first successful CODE0x2fc..320.
	heading = 4
	phase = 0
	counter = 0
	frozen = true
	initialized = true


func record_player(position: Vector2i, network) -> void:
	if network.is_switch(position) and (history.is_empty() or history.front() != position):
		history.push_front(position)
		if history.size() > 3: # TIME145d..149b includes indices0..2.
			history.resize(3)


func has_presence(position: Vector2i) -> bool:
	return initialized and cell == position


# TIME85f increments counter every callback; turns at phase1, commits at phase3.
func advance(network, rng: RandomNumberGenerator, traps: Array = []) -> bool:
	if not initialized or frozen:
		return false
	counter += 1
	if counter != 2:
		return false
	counter = 0
	phase += 1
	var committed := phase == 3
	var motion = load("res://scripts/roamer_motion.gd")
	if committed:
		phase = 0
		var moved: Dictionary = motion.step(cell, heading, 8, network, traps)
		cell = moved.cell
		heading = moved.heading
	heading = motion.turn(cell, heading, phase, history, network, rng)
	return committed


func snapshot() -> Dictionary:
	var visited: Array = []
	for item in history:
		visited.append([item.x, item.y])
	return {"initialized": initialized, "cell": [cell.x, cell.y], "heading": heading,
		"phase": phase, "counter": counter, "frozen": frozen, "history": visited}


func restore(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 7 or not value.get("initialized") is bool or not value.get("frozen") is bool:
		return false
	if not _cell(value.get("cell")) or not value.get("history") is Array or value.history.size() > 3:
		return false
	for key in ["heading", "phase", "counter"]:
		if not _integer(value.get(key)):
			return false
	if value.heading < 1 or value.heading > 9 or value.phase < 0 or value.phase > 2 or value.counter < 0 or value.counter > 1:
		return false
	var visited: Array[Vector2i] = []
	for item in value.history:
		if not _cell(item):
			return false
		visited.append(Vector2i(int(item[0]), int(item[1])))
	if value.frozen and (not value.initialized or int(value.cell[0]) != 126 or int(value.cell[1]) != 15 or value.heading != 4 or value.phase != 0 or value.counter != 0):
		return false
	initialized = value.initialized
	cell = Vector2i(int(value.cell[0]), int(value.cell[1]))
	heading = int(value.heading)
	phase = int(value.phase)
	counter = int(value.counter)
	frozen = value.frozen
	history = visited
	return true


static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(value) and value == floor(value)


static func _cell(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _integer(value[0]) and _integer(value[1]) and value[0] >= 0 and value[0] < 160 and value[1] >= 0 and value[1] < 72
