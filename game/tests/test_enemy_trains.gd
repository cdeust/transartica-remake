extends SceneTree

const EnemyTrains = preload("res://scripts/enemy_trains.gd")
const RailNetwork = preload("res://scripts/rail_network.gd")
const WorldData = preload("res://scripts/world_data.gd")

var map_bytes := PackedByteArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var world = WorldData.new()
	if not world.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")):
		push_error("private reference map unavailable")
		quit(1)
		return
	map_bytes = world.map_bytes
	_test_spawn_free_slot_and_rng_order(failures)
	_test_spawn_slot_limit_and_map_bit(failures)
	_test_spawn_points_are_rail_tiles(failures)
	_test_hour_and_day_scheduling(failures)
	_test_scripted_slot(failures)
	_test_straight_movement_and_bit_swap(failures)
	_test_curve_and_switch_follows_player_history(failures)
	_test_switch_random_without_history(failures)
	_test_damaged_track_waits(failures)
	_test_obstacle_bounce(failures)
	_test_encounter_detection(failures)
	_test_removal(failures)
	_test_snapshot_and_restore(failures)
	if failures.is_empty():
		print("PASS: enemy spawn, scheduling, movement, switches, obstacles, encounter, persistence")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _network() -> RailNetwork:
	var network := RailNetwork.new()
	network.load_bytes(map_bytes)
	return network


func _synthetic(cells: Dictionary) -> RailNetwork:
	var bytes := PackedByteArray()
	bytes.resize(RailNetwork.WIDTH * RailNetwork.HEIGHT)
	for cell in cells:
		var value: int = cells[cell]
		bytes[cell.x * RailNetwork.HEIGHT + cell.y] = value + 256 if value < 0 else value
	var network := RailNetwork.new()
	network.load_bytes(bytes)
	return network


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _test_spawn_free_slot_and_rng_order(failures: Array[String]) -> void:
	var enemies := EnemyTrains.new()
	var rng := _seeded_rng(1)
	var point_index := rng.randi_range(0, EnemyTrains.SPAWN_POINTS.size() - 1)
	var strength_draw_a := rng.randi_range(0, 1)
	var strength_draw_b := rng.randi_range(0, 5)
	rng.seed = 1
	var slot := enemies.spawn(0, rng)
	_check(slot == 0, "first spawn fills slot 0", failures)
	var point: Array = EnemyTrains.SPAWN_POINTS[point_index]
	_check(enemies.slots[0][EnemyTrains.DX] == point[0] and enemies.slots[0][EnemyTrains.Y] == point[1] \
			and enemies.slots[0][EnemyTrains.HEADING] == point[2], "spawn point matches rnd(9) draw order", failures)
	var expected_strength: int = 0 / 2 + 0 + 1 + strength_draw_a + 20 * strength_draw_b
	_check(enemies.slots[0][EnemyTrains.STRENGTH] == expected_strength, "strength consumes rnd(2) then rnd(6) in that order", failures)
	_check(enemies.slots[0][EnemyTrains.STATE] == 1 and enemies.slots[0][EnemyTrains.PHASE] == 2, "spawn sets state 1 and phase 2", failures)
	_check(enemies.slots[0][EnemyTrains.SPEED] == 20, "speed is 20 + slot/2 + difficulty for slot 0 at difficulty 0", failures)


func _test_spawn_slot_limit_and_map_bit(failures: Array[String]) -> void:
	var enemies := EnemyTrains.new()
	var rng := _seeded_rng(7)
	for slot in EnemyTrains.SPAWN_SLOT_LIMIT + 1:
		_check(enemies.spawn(0, rng) == slot, "spawn fills slots 0..28 in order", failures)
	_check(enemies.spawn(0, rng) == -1, "slot 29 is never filled by the periodic spawn", failures)
	for slot in EnemyTrains.SPAWN_SLOT_LIMIT + 1:
		_check(enemies.has_presence(enemies.cell(slot)), "spawn marks the map-bit mirror at the spawn cell", failures)


func _test_spawn_points_are_rail_tiles(failures: Array[String]) -> void:
	var network := _network()
	for point in EnemyTrains.SPAWN_POINTS:
		var cell := Vector2i(point[0] + 40, point[1])
		var heading: int = point[2]
		var candidate: Vector2i = cell + network.DELTAS[heading]
		_check(network.tile(cell) != 0, "spawn cell %s is a rail tile" % cell, failures)
		_check(network.entry_boundary(candidate).is_empty() or network.tile(candidate) != 0, "spawn cell %s has a plausible exit toward heading %d" % [cell, heading], failures)


func _test_hour_and_day_scheduling(failures: Array[String]) -> void:
	var enemies := EnemyTrains.new()
	var rng := _seeded_rng(2)
	_check(enemies.maybe_spawn_on_hour(1, 4, rng) == -1, "difficulty 4 does not spawn off the 12h boundary", failures)
	_check(enemies.maybe_spawn_on_hour(12, 4, rng) == 0, "difficulty 4 spawns every 12h", failures)
	_check(enemies.maybe_spawn_on_hour(1, 0, rng) == -1, "difficulty 0 ignores the hourly hook", failures)
	var day_enemies := EnemyTrains.new()
	_check(day_enemies.maybe_spawn_on_day(1, 0, rng) == -1, "difficulty 0: day 1 is not a multiple of 4", failures)
	_check(day_enemies.maybe_spawn_on_day(4, 0, rng) == 0, "difficulty 0 spawns every 4 days", failures)
	var diff2 := EnemyTrains.new()
	_check(diff2.maybe_spawn_on_day(2, 2, rng) == 0, "difficulty 2 spawns every (4-2)=2 days", failures)


func _test_scripted_slot(failures: Array[String]) -> void:
	var enemies := EnemyTrains.new()
	enemies.sync_scripted_slot(EnemyTrains.SCRIPTED_SPAWN_CELL)
	_check(enemies.slots[29] == EnemyTrains.SCRIPTED_RECORD, "entering (152,66) writes the exact scripted record", failures)
	_check(enemies.has_presence(EnemyTrains.SCRIPTED_MARK_CELL), "scripted spawn marks (154,62)", failures)
	enemies.sync_scripted_slot(EnemyTrains.SCRIPTED_REMOVE_CELL)
	_check(enemies.slots[29][EnemyTrains.STATE] == 0, "leaving to (151,66) fully clears slot 29", failures)
	_check(not enemies.has_presence(EnemyTrains.SCRIPTED_MARK_CELL), "leaving clears the map-bit mirror", failures)
	enemies.remove(29)
	enemies.sync_scripted_slot(EnemyTrains.SCRIPTED_SPAWN_CELL)
	_check(enemies.slots[29][EnemyTrains.STATE] == EnemyTrains.REMOVED_STATE, "a removed slot 29 does not respawn", failures)


func _test_straight_movement_and_bit_swap(failures: Array[String]) -> void:
	var cells := {}
	for x in range(10, 20):
		cells[Vector2i(x, 62)] = 2
	var network := _synthetic(cells)
	var enemies := EnemyTrains.new()
	var rng := _seeded_rng(3)
	var slot := enemies.spawn(0, rng)
	enemies.slots[slot][EnemyTrains.DX] = 10 - 40
	enemies.slots[slot][EnemyTrains.Y] = 62
	enemies.slots[slot][EnemyTrains.HEADING] = 6
	enemies.slots[slot][EnemyTrains.SPEED] = 450
	enemies._set_bit(Vector2i(10, 62), true)
	for cycle in 200:
		enemies.advance_cycle(network, rng, 6)
	_check(enemies.cell(slot).x > 10, "a moving slot advances east along a straight track", failures)
	_check(not enemies.has_presence(Vector2i(10, 62)), "the old cell's bit is cleared once the enemy leaves it", failures)
	_check(enemies.has_presence(enemies.cell(slot)), "the new cell's bit is set", failures)


func _test_curve_and_switch_follows_player_history(failures: Array[String]) -> void:
	var network := _synthetic({Vector2i(6, 5): 22, Vector2i(7, 5): 2})
	network.toggle_switch(Vector2i(6, 5)) # now 23, diverges south-east.
	var enemies := EnemyTrains.new()
	enemies.record_player_position(Vector2i(6, 5), network)
	var rng := _seeded_rng(5)
	var heading := enemies._choose_heading(Vector2i(6, 5), 6, 0, network, rng)
	_check(heading == 3, "an enemy with positive strength standing on the player's last switch cell follows the diverged switch", failures)


func _test_switch_random_without_history(failures: Array[String]) -> void:
	var network := _synthetic({Vector2i(6, 5): 22, Vector2i(7, 5): 2})
	var enemies := EnemyTrains.new()
	var straight_rng := _seeded_rng(11)
	var seen_straight := false
	var seen_diverge := false
	for draw in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = draw
		var heading := enemies._choose_heading(Vector2i(6, 5), 6, 0, network, rng)
		if heading == 6:
			seen_straight = true
		elif heading == 3:
			seen_diverge = true
	_check(seen_straight and seen_diverge, "without a history match the switch choice is rnd(2)-driven and can go either way", failures)
	var negative_strength := enemies._choose_heading(Vector2i(6, 5), 6, -1, network, straight_rng)
	_check(negative_strength == 6 or negative_strength == 3, "negative strength always uses the random branch", failures)


func _test_damaged_track_waits(failures: Array[String]) -> void:
	var network := _synthetic({Vector2i(10, 62): 2, Vector2i(11, 62): -50})
	var enemies := EnemyTrains.new()
	var rng := _seeded_rng(4)
	var slot := enemies.spawn(0, rng)
	enemies.slots[slot][EnemyTrains.DX] = 10 - 40
	enemies.slots[slot][EnemyTrains.Y] = 62
	enemies.slots[slot][EnemyTrains.HEADING] = 6
	enemies.slots[slot][EnemyTrains.SPEED] = 450
	for cycle in 50:
		enemies.advance_cycle(network, rng, 6)
	_check(enemies.cell(slot) == Vector2i(10, 62), "damaged track refuses the move", failures)
	_check(absi(enemies.slots[slot][EnemyTrains.STATE]) >= 1, "damaged track sets a wait state instead of a bounce", failures)


func _test_obstacle_bounce(failures: Array[String]) -> void:
	var network := _synthetic({Vector2i(10, 62): 2, Vector2i(11, 62): 34})
	var enemies := EnemyTrains.new()
	var rng := _seeded_rng(6)
	var slot := enemies.spawn(0, rng)
	enemies.slots[slot][EnemyTrains.DX] = 10 - 40
	enemies.slots[slot][EnemyTrains.Y] = 62
	enemies.slots[slot][EnemyTrains.HEADING] = 6
	enemies.slots[slot][EnemyTrains.SPEED] = 450
	# Two cycles reach the candidate step exactly once (spawn phase is already 2);
	# further cycles would keep driving the now-reversed heading through open (tile
	# 0) cells this synthetic map leaves undefined, which is not an obstacle.
	for cycle in 2:
		enemies.advance_cycle(network, rng, 6)
	_check(enemies.cell(slot) == Vector2i(10, 62), "an obstacle tile keeps the enemy at its cell", failures)
	_check(enemies.slots[slot][EnemyTrains.HEADING] == 4, "the obstacle reverses the heading (6 -> 4)", failures)
	_check(enemies.slots[slot][EnemyTrains.STATE] == -1, "the obstacle flips the state sign", failures)


func _test_encounter_detection(failures: Array[String]) -> void:
	var enemies := EnemyTrains.new()
	var rng := _seeded_rng(9)
	var slot := enemies.spawn(0, rng)
	var occupied := enemies.cell(slot)
	_check(enemies.encounter_at(occupied) == slot, "the player's candidate cell resolves to the occupying slot", failures)
	_check(enemies.encounter_at(occupied + Vector2i(1, 0)) == -1, "an empty cell is not an encounter", failures)


func _test_removal(failures: Array[String]) -> void:
	var enemies := EnemyTrains.new()
	var rng := _seeded_rng(10)
	var slot := enemies.spawn(0, rng)
	var occupied := enemies.cell(slot)
	enemies.remove(slot)
	_check(enemies.slots[slot][EnemyTrains.STATE] == EnemyTrains.REMOVED_STATE, "removal sets state 2", failures)
	_check(enemies.slots[slot][EnemyTrains.STRENGTH] == 0, "removal zeroes fields 1..7", failures)
	_check(not enemies.has_presence(occupied), "removal clears the map-bit mirror", failures)
	_check(enemies.encounter_at(occupied) == -1, "a removed slot is not an encounter", failures)
	var rescan := EnemyTrains.new()
	for _fill in EnemyTrains.SPAWN_SLOT_LIMIT + 1:
		rescan.spawn(0, rng)
	rescan.remove(0)
	_check(rescan.spawn(0, rng) == -1, "a removed slot is never reused by the free-slot scan", failures)


func _test_snapshot_and_restore(failures: Array[String]) -> void:
	var enemies := EnemyTrains.new()
	var rng := _seeded_rng(12)
	enemies.spawn(0, rng)
	enemies.spawn(0, rng)
	var saved := enemies.snapshot()
	var restored := EnemyTrains.new()
	_check(restored.restore(saved) and restored.slots == enemies.slots, "restore reproduces the exact table", failures)
	_check(restored.has_presence(restored.cell(0)) and restored.has_presence(restored.cell(1)), "restore rebuilds the map-bit mirror", failures)
	_check(not EnemyTrains.new().restore({"version": 1, "slots": []}), "wrong slot count is refused", failures)
	_check(not EnemyTrains.new().restore({"version": 2, "slots": enemies.slots}), "wrong version is refused", failures)
