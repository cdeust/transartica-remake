extends SceneTree

const MineTable = preload("res://scripts/mines.gd")
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
	_test_free_slot_and_used(failures)
	_test_create_horizontal_placeholder(failures)
	_test_create_vertical_placeholder(failures)
	_test_create_finds_nothing_without_a_neighbor(failures)
	_test_create_respects_day_limit(failures)
	_test_create_respects_full_table(failures)
	_test_deplete_timing(failures)
	_test_deplete_keeps_decaying_after_zero(failures)
	_test_prospect_yes_and_no(failures)
	_test_slot_for_cell(failures)
	_test_snapshot_and_restore(failures)
	_test_real_map_invariants(failures)
	if failures.is_empty():
		print("PASS: mine creation, depletion, prospecting, persistence")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _synthetic_network(cells: Dictionary) -> RailNetwork:
	var bytes := PackedByteArray()
	bytes.resize(RailNetwork.WIDTH * RailNetwork.HEIGHT)
	for cell in cells:
		var value: int = cells[cell]
		bytes[cell.x * RailNetwork.HEIGHT + cell.y] = value + 256 if value < 0 else value
	var network := RailNetwork.new()
	network.load_bytes(bytes)
	return network


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_free_slot_and_used(failures: Array[String]) -> void:
	var table := MineTable.new()
	_check(table.records.size() == MineTable.SLOT_COUNT, "table starts with 36 slots", failures)
	_check(table.find_free_slot() == 0, "an empty table's first free slot is 0", failures)
	table.records[0] = [10, 20, 5, 42]
	_check(table.find_free_slot() == 1, "an occupied slot 0 leaves slot 1 free", failures)
	_check(MineTable.is_used(table.records[0]) and not MineTable.is_used(table.records[1]), "occupancy follows the signed-day sentinel", failures)
	_check(not MineTable.is_anthracite(table.records[0]) and MineTable.mine_cell(table.records[0]) == Vector2i(50, 20), "positive day is lignite; cell is field0+40, field1", failures)


# YODA 0x1f8e: candidate (30,30)==2, west neighbor (29,30)==18 -> switch 20 at (30,30), mine at (29,29).
func _test_create_horizontal_placeholder(failures: Array[String]) -> void:
	var network := _synthetic_network({Vector2i(30, 30): 2, Vector2i(29, 30): 18})
	var table := MineTable.new()
	# rnd(138)+11 then rnd(50)+11 must land the search window on (30,30); seed picked by trial.
	var rng := _rng(1)
	var cx := rng.randi_range(0, MineTable.CENTER_X_SPREAD - 1) + MineTable.CENTER_MIN
	var cy := rng.randi_range(0, MineTable.CENTER_Y_SPREAD - 1) + MineTable.CENTER_MIN
	network = _synthetic_network({Vector2i(cx, cy): 2, Vector2i(cx - 1, cy): 18})
	rng = _rng(1)
	var writes := table.create(1, network, rng)
	_check(writes.size() == 2 and writes.get(Vector2i(cx, cy)) == 20 and writes.get(Vector2i(cx - 1, cy - 1)) == 78, "code-2 candidate with a west 18 neighbor becomes switch 20, mine on the NW diagonal", failures)
	var record: Array = table.records[0]
	_check(MineTable.mine_cell(record) == Vector2i(cx - 1, cy - 1), "the record stores the mine cell, not the switch cell", failures)
	_check(record[MineTable.FIELD_WEALTH] >= MineTable.WEALTH_MIN and record[MineTable.FIELD_WEALTH] <= MineTable.WEALTH_MIN + MineTable.WEALTH_SPREAD - 1, "wealth index is rnd(10)+40", failures)


# YODA 0x2142: candidate ==3, north neighbor (x,y-1)==28 -> switch 32, mine on the NW diagonal.
func _test_create_vertical_placeholder(failures: Array[String]) -> void:
	var table := MineTable.new()
	var rng := _rng(1)
	var cx := rng.randi_range(0, MineTable.CENTER_X_SPREAD - 1) + MineTable.CENTER_MIN
	var cy := rng.randi_range(0, MineTable.CENTER_Y_SPREAD - 1) + MineTable.CENTER_MIN
	var network := _synthetic_network({Vector2i(cx, cy): 3, Vector2i(cx, cy - 1): 28})
	rng = _rng(1)
	var writes := table.create(1, network, rng)
	_check(writes.get(Vector2i(cx, cy)) == 32 and writes.get(Vector2i(cx - 1, cy - 1)) == 78, "code-3 candidate with a north 28 neighbor becomes switch 32, mine on the NW diagonal", failures)


func _test_create_finds_nothing_without_a_neighbor(failures: Array[String]) -> void:
	var table := MineTable.new()
	var rng := _rng(1)
	var cx := rng.randi_range(0, MineTable.CENTER_X_SPREAD - 1) + MineTable.CENTER_MIN
	var cy := rng.randi_range(0, MineTable.CENTER_Y_SPREAD - 1) + MineTable.CENTER_MIN
	var network := _synthetic_network({Vector2i(cx, cy): 2})
	rng = _rng(1)
	var writes := table.create(1, network, rng)
	_check(writes.is_empty() and table.find_free_slot() == 0, "a placeholder with no qualifying neighbor creates nothing and keeps the slot free", failures)


func _test_create_respects_day_limit(failures: Array[String]) -> void:
	var table := MineTable.new()
	var network := _synthetic_network({})
	var writes := table.create(MineTable.CREATION_DAY_LIMIT + 1, network, _rng(1))
	_check(writes.is_empty(), "day > 127 never creates a mine", failures)
	var at_limit := table.create(MineTable.CREATION_DAY_LIMIT, network, _rng(1))
	_check(at_limit.is_empty(), "an empty search window still yields no writes at the limit day", failures)


func _test_create_respects_full_table(failures: Array[String]) -> void:
	var table := MineTable.new()
	for index in MineTable.SLOT_COUNT:
		table.records[index] = [0, 0, index + 1, 40]
	var network := _synthetic_network({Vector2i(30, 30): 2, Vector2i(29, 30): 18})
	var writes := table.create(1, network, _rng(1))
	_check(writes.is_empty(), "a full 36-slot table blocks creation even with a valid site", failures)


func _test_deplete_timing(failures: Array[String]) -> void:
	var table := MineTable.new()
	table.records[0] = [10, 20, 5, MineTable.WEALTH_MIN]
	var writes := table.deplete()
	_check(writes.is_empty() and table.records[0][MineTable.FIELD_WEALTH] == MineTable.WEALTH_MIN - MineTable.DECAY_PER_TICK, "one tick removes 5 without reaching depletion", failures)
	var ticks := 0
	while writes.is_empty() and ticks < 20:
		writes = table.deplete()
		ticks += 1
	_check(writes.get(Vector2i(50, 20)) == MineTable.DEPLETED_TILE, "wealth below 1 writes the depleted tile 79 at the mine cell", failures)
	_check(ticks == int((MineTable.WEALTH_MIN - MineTable.DECAY_PER_TICK - MineTable.DEPLETED_BELOW) / float(MineTable.DECAY_PER_TICK)) + 1, "depletion timing matches wealth/5 rollovers, YODA 0x1e52", failures)


func _test_deplete_keeps_decaying_after_zero(failures: Array[String]) -> void:
	var table := MineTable.new()
	table.records[0] = [10, 20, 5, MineTable.DEPLETED_BELOW - 1]
	table.deplete()
	table.deplete()
	_check(table.records[0][MineTable.FIELD_WEALTH] == MineTable.DEPLETED_BELOW - 1 - 2 * MineTable.DECAY_PER_TICK, "no source resets a depleted slot; wealth keeps falling (mines.md 1/2)", failures)
	_check(MineTable.is_used(table.records[0]), "a depleted slot stays occupied forever", failures)


func _test_prospect_yes_and_no(failures: Array[String]) -> void:
	var table := MineTable.new()
	table.records[3] = [10, 20, 5, 45]
	var no_writes := table.prospect(3, false)
	_check(no_writes.is_empty() and table.records[3][MineTable.FIELD_WEALTH] == 45, "refusing prospecting writes nothing and leaves the record untouched", failures)
	var yes_writes := table.prospect(3, true)
	_check(yes_writes.get(Vector2i(50, 20)) == MineTable.DEPLETED_TILE, "accepting prospecting writes tile 79 at the mine cell", failures)
	_check(table.records[3][MineTable.FIELD_WEALTH] == -1, "accepting prospecting forces wealth to -1, YODA 0x25e2", failures)
	_check(table.prospect(3, true).get(Vector2i(50, 20)) == MineTable.DEPLETED_TILE, "an already-depleted mine still resolves to 79 on YES", failures)
	_check(table.prospect(9, true).is_empty(), "an empty slot cannot be prospected", failures)


func _test_slot_for_cell(failures: Array[String]) -> void:
	var table := MineTable.new()
	table.records[7] = [10, 20, -5, 45]
	_check(table.slot_for_cell(Vector2i(50, 20)) == 7, "TIME 0x2509 resolves a cell to its slot", failures)
	_check(table.slot_for_cell(Vector2i(51, 20)) == -1, "an unrelated cell resolves to no slot", failures)
	_check(MineTable.is_anthracite(table.records[7]), "negative day encodes anthracite", failures)


func _test_snapshot_and_restore(failures: Array[String]) -> void:
	var table := MineTable.new()
	table.records[2] = [10, 20, 5, 45]
	var saved := table.snapshot()
	var restored := MineTable.new()
	_check(restored.restore(saved) and restored.snapshot() == saved, "snapshot round-trips through restore", failures)
	_check(not restored.restore([[0, 0, 0, 0]]), "restore rejects a table with the wrong slot count", failures)
	var non_numeric: Array = []
	non_numeric.append([0, 0, 0, "x"])
	for _index in MineTable.SLOT_COUNT - 1:
		non_numeric.append([0, 0, 0, 0])
	_check(not restored.restore(non_numeric), "restore rejects a non-numeric field", failures)
	var bad := saved.duplicate(true)
	bad[2][MineTable.FIELD_WEALTH] = MineTable.WEALTH_MIN + MineTable.WEALTH_SPREAD
	_check(not restored.restore(bad), "restore rejects a wealth index above the rnd(10)+40 ceiling", failures)


# Every placement create() finds on the real map must sit on a genuine off-track diagonal
# next to the matching existing switch family (rail_network.gd SWITCH_RULES bases).
func _test_real_map_invariants(failures: Array[String]) -> void:
	var network := RailNetwork.new()
	network.load_bytes(map_bytes)
	var found := 0
	for seed_value in range(1, 60):
		var table := MineTable.new()
		var writes := table.create(1, network, _rng(seed_value))
		if writes.is_empty():
			continue
		found += 1
		var record: Array = table.records[0]
		var mine_at := MineTable.mine_cell(record)
		var switch_at: Vector2i
		var switch_code: int = -1
		for cell in writes:
			if writes[cell] != MineTable.MINE_TILE:
				switch_at = cell
				switch_code = writes[cell]
		_check(writes.get(mine_at) == MineTable.MINE_TILE, "the recorded mine cell is exactly the written 78 cell", failures)
		_check(abs(mine_at.x - switch_at.x) == 1 and abs(mine_at.y - switch_at.y) == 1, "the mine sits diagonally adjacent to its switch", failures)
		_check(RailNetwork.SWITCH_RULES.has(switch_code), "the switch code belongs to the rail-network switch table", failures)
	_check(found > 0, "at least one of 60 seeded centers finds a real placement on the shipped map", failures)
