extends SceneTree

const Battle = preload("res://scripts/automatic_combat.gd")
const Wagons = preload("res://scripts/train_wagons.gd")
const EngineState = preload("res://scripts/engine_state.gd")
var failures: Array[String] = []


func _initialize() -> void:
	_test_loss()
	_test_original_debit_bugs()
	_test_random_order()
	_test_capacity_and_replay()
	_test_booty_capacity()
	_test_capture_switch()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: automatic combat loss, original debit bugs, phase RNG order, capacity and seeded replay")
	quit(0 if failures.is_empty() else 1)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_loss() -> void:
	for strength in [0, 1000]:
		var wagons = Wagons.new()
		var engine = EngineState.new()
		var before: Dictionary = engine.snapshot()
		var cargo: Array = wagons.snapshot()
		var result: Dictionary = Battle.resolve(wagons, engine, strength, _rng(17))
		_check(not result.won and result.epitaph_id == 105, "zero/negative margin ends game")
		_check(engine.snapshot() == before and wagons.snapshot() == cargo, "loss changes no cargo, fuel or mass")
		_check(result.wagons_captured == 0 and result.scrapped_indices.is_empty(), "loss has no booty or scrap")


func _test_original_debit_bugs() -> void:
	var wagons = Wagons.new()
	wagons.wagons = [[23,0,0,2], [23,0,0,10], [23,0,0,10], [24,0,0,10],
		[17,0,0,24], [7,0,0,2], [7,0,0,10], [7,3,0,10]]
	Battle._debit_casualties(wagons, 7, 5)
	var expected := [0, 5, 5, 10, 19, 0, 7, 7]
	for index in expected.size():
		_check(wagons.wagons[index][3] == expected[index], "source sequential debit at wagon %d" % index)
	# Underflow carries a remainder; sufficient payment does not clear it.
	# TYPE24 is untouched unless quantity24; destroyed records are not filtered.


func _test_random_order() -> void:
	var wagons = Wagons.new()
	wagons.wagons = [[1,0,0,0], [21,0,0,0], [2,0,0,0], [3,0,0,0], [23,0,0,75], [24,0,0,75]]
	var engine = EngineState.new()
	engine.lignite = 100
	engine.anthracite = 0
	var rng := _rng(42)
	var oracle := _rng(42)
	# strength200: a2,b0,n2; phase44 still consumes its three report draws.
	oracle.randi_range(0, 0)
	oracle.randi() # rnd(0) still consumes a value.
	oracle.randi_range(0, 11)
	oracle.randi_range(0, 14)
	for attempt in 8: # margin1, all six fixture types reject scrap.
		oracle.randi_range(0, 5)
	var expected_coal := (5 + oracle.randi_range(0, 49)) * 10
	oracle.randi_range(0, 5) # slaves drawn despite absent prison capacity.
	var kind := 17 + oracle.randi_range(0, 1)
	var goods := oracle.randi_range(0, 15) + 1
	var capacity := 10 if goods in [2, 3] else 40
	if goods in [5, 6, 8, 9]:
		goods = 10 + oracle.randi_range(0, 6)
	var quantity := oracle.randi_range(0, (capacity / 2 if kind == 17 else capacity) - 1) + 1
	var result: Dictionary = Battle.resolve(wagons, engine, 200, rng)
	_check(result.won and result.margin == 1 and result.soldiers_lost == 75, "aggregate source margin and casualties")
	_check(wagons.wagons[4][3] == 0 and wagons.wagons[5][3] == 75, "ordinary XL barracks escape original buggy debit")
	_check(result.coal_gained == expected_coal and result.slaves_gained == 0, "booty occurs after eight failed scrap attempts")
	_check(result.captured == [[kind, 0, goods, quantity]] and rng.state == oracle.state, "capture and final RNG state follow original phase order")


func _test_capacity_and_replay() -> void:
	var wagons = Wagons.new()
	wagons.wagons.clear()
	for index in 10:
		wagons.wagons.append([11, 0, 0, 0])
	while wagons.count() < 98:
		wagons.wagons.append([24, 0, 0, 0])
	var second = Wagons.new()
	second.restore(wagons.snapshot())
	var engine = EngineState.new()
	var other_engine = EngineState.new()
	var result: Dictionary = Battle.resolve(wagons, engine, 0, _rng(24))
	var replay: Dictionary = Battle.resolve(second, other_engine, 0, _rng(24))
	_check(result.won and result.margin == 10 and result.scrapped_indices.is_empty(), "large margin has no scrap attempts")
	_check(wagons.count() == 100 and result.wagons_captured == 2, "capture stops at original 100-wagon bound")
	_check(result.coal_gained == 0 and result.slaves_gained == 0, "booty respects absent tender/prison capacity")
	_check(result == replay and wagons.snapshot() == second.snapshot() and engine.snapshot() == other_engine.snapshot(), "seeded full transaction repeats exactly")
	_check(engine.train_mass == wagons.mass(), "live train mass follows final transaction")


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _test_booty_capacity() -> void:
	var wagons = Wagons.new()
	wagons.wagons = [[21,0,0,0], [5,0,1,29], [5,0,1,30], [6,0,1,99]]
	for index in 10:
		wagons.wagons.append([11,0,0,0])
	var engine = EngineState.new()
	engine.lignite = 4995
	engine.anthracite = 0
	var result: Dictionary = Battle.resolve(wagons, engine, 50, _rng(3))
	_check(result.margin == 10 and result.coal_gained == 5, "coal respects remaining tender room")
	_check(result.slaves_gained == 32, "prison gate29 fills60, gate30 skipped, alcatraz fills100")
	_check(wagons.wagons[1][3] == 60 and wagons.wagons[2][3] == 30 and wagons.wagons[3][3] == 100, "booty uses original per-wagon capacities")


func _test_capture_switch() -> void:
	var wagons = Wagons.new()
	wagons.wagons.clear()
	Battle._capture(wagons, 100, _rng(42))
	var seen: Dictionary = {}
	for wagon in wagons.wagons:
		seen[wagon[2]] = true
		var cap := 10 if wagon[2] in [2, 3] else 40
		cap = cap / 2 if wagon[0] == 17 else cap
		_check(wagon[3] >= 1 and wagon[3] <= cap, "decoded cswitch2 capacity applies")
	_check(seen.has(1) and seen.has(2) and seen.has(3) and seen.has(4) and seen.has(7), "seeded fixture exercises retained goods and capacity10 branches")
