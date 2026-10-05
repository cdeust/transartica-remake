extends RefCounted
# MIT. WDECOR0x58c9..6053 commit battle result exactly once.
const Outcome = preload("res://scripts/combat_outcome.gd")
const Setup = preload("res://scripts/combat_setup.gd")
const Wagons = preload("res://scripts/train_wagons.gd")
const Survivors = preload("res://scripts/tactical_survivors.gd")

static func commit(state, wagons, engine, spies: Array = []) -> Dictionary:
	if state.outcome == 0 or state.settled:
		return {}
	state.settled = true
	var pools: Dictionary = state.survivors #8528/8530; distinct from army strength.
	var result := {"won": state.outcome == 1, "soldiers_lost": state.initial_pools.soldiers - pools.soldiers, "mammoths_lost": state.initial_pools.mammoths - pools.mammoths, "coal_gained": 0, "slaves_gained": 0, "wagons_captured": 0, "captured": [], "scrapped_indices": []}
	if state.outcome == 2:
		result.epitaph_id = 105
		return result
	_write_player(state, wagons, result)
	Outcome.apply_destruction(wagons, engine, spies, state.rng)
	var coal_before: int = engine.lignite
	Outcome.win_coal(wagons, engine, state.trains[1].size(), state.rng)
	result.coal_gained = engine.lignite - coal_before
	result.slaves_gained = Outcome.win_slaves(wagons, state.trains[1].size(), state.rng)
	Survivors.redistribute(state,wagons)
	#605a/6067: final reports include losses from insufficient intact capacity.
	result.soldiers_lost = state.initial_pools.soldiers-state.survivors.soldiers
	result.mammoths_lost = state.initial_pools.mammoths-state.survivors.mammoths
	_capture(state, wagons, result)
	engine.train_mass = wagons.mass()
	return result

static func _write_player(state, wagons, result: Dictionary) -> void:
	var roster := 0
	for index in wagons.count():
		var car: Dictionary = state.trains[0][roster]
		var health: int = car.health
		if car.class == Setup.LOCOMOTIVE:
			health = (health + state.trains[0][roster + 1].health) / 2
			roster += 1
		wagons.wagons[index][Wagons.STATE] = 3 - health #0x590b/58d9.
		if car.class in [Setup.BARRACKS, Setup.LIVESTOCK]:
			wagons.wagons[index][Wagons.QUANTITY] = car.quantity
		if health <= 0:
			result.scrapped_indices.append(index)
		roster += 1

static func _capture(state, wagons, result: Dictionary) -> void:
	#0x5aa5 alive merchandise only; maximum6, original100 wagon cap.
	for car in state.trains[1]:
		if car.class != Setup.MERCHANDISE or car.health <= 0:
			continue
		if result.wagons_captured >= 6 or wagons.count() >= Wagons.MAX_WAGONS:
			break
		var kind: int = 17 + state.rnd(2)
		var goods: int = state.rnd(16) + 1
		var capacity := 40
		# cswitch2 base -2 means goods−2, confirmed by ALIS opcodes.c.
		if goods in [2,3]:
			capacity = 10
		elif goods in [5,6,8,9]:
			goods = 10 + state.rnd(7)
		var quantity: int = state.rnd(capacity / 2 if kind == 17 else capacity) + 1
		var captured := [kind, 3 - car.health, goods, quantity]
		wagons.wagons.append(captured)
		result.captured.append(captured.duplicate())
		result.wagons_captured += 1
