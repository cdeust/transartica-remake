extends RefCounted

# MIT. TEXTEK phases44→45→46, source: tasks/evidence/automatic-combat-integration.md.
const Outcome = preload("res://scripts/combat_outcome.gd")
const Wagons = preload("res://scripts/train_wagons.gd")


static func resolve(wagons, engine, strength: int, rng: RandomNumberGenerator) -> Dictionary:
	assert(strength >= 0 and wagons.count() > 0 and rng != null)
	var pools: Dictionary = Outcome.auto_resolve_pools(wagons)
	var potential: int = Outcome.potential(pools)
	var margin: int = Outcome.margin(potential, strength)
	var enemy := _enemy_report(strength, rng)
	var result := {"won": margin > 0, "margin": margin, "potential": potential,
		"enemy": enemy, "soldiers_lost": 0, "mammoths_lost": 0,
		"coal_gained": 0, "slaves_gained": 0, "wagons_captured": 0,
		"scrapped_indices": [], "captured": []}
	# TEXTEK0x5435: phase44 loss returns before phase45 mutates the train.
	if not result.won:
		result.epitaph_id = 105
		return result
	result.soldiers_lost = Outcome.auto_resolve_casualties(pools.soldiers, margin)
	result.mammoths_lost = Outcome.auto_resolve_casualties(pools.mammoths, margin)
	_debit_casualties(wagons, result.soldiers_lost, result.mammoths_lost)
	result.scrapped_indices = _scrap(wagons, Outcome.auto_resolve_scrap_count(margin), rng)
	# Phase46 follows scrap: a lost prison cannot receive the subsequent slaves.
	var coal_before: int = engine.lignite
	Outcome.auto_resolve_coal(wagons, engine, enemy.wagons, rng)
	result.coal_gained = engine.lignite - coal_before
	result.slaves_gained = Outcome.auto_resolve_slaves(wagons, enemy.wagons, rng)
	var count_before: int = wagons.count()
	_capture(wagons, Outcome.auto_resolve_captured_count(margin), rng)
	result.wagons_captured = wagons.count() - count_before
	result.captured = wagons.wagons.slice(count_before).duplicate(true)
	engine.train_mass = wagons.mass()
	return result


static func _rnd(rng: RandomNumberGenerator, bound: int) -> int:
	# ALIS ornd advances even with bound0 (opernames.c433–437).
	if bound == 0:
		rng.randi()
		return 0
	return rng.randi_range(0, bound - 1)


static func _enemy_report(strength: int, rng: RandomNumberGenerator) -> Dictionary:
	var a := strength / 100
	var b := strength % 100
	var half := (a + b) / 2
	var count := _rnd(rng, half) + half + 1 # TEXTEK0x4ae8.
	var trading := count * b / (b + a + 1) # 0x527c.
	var gun_pool := (count - trading - 1) / 2
	var first_guns := _rnd(rng, gun_pool) # 0x52a1, display roll still advances RNG.
	var soldiers := count * 6 + _rnd(rng, count * 6) # 0x52d5.
	var mammoths := soldiers / (15 + _rnd(rng, 15)) + 1 # 0x52e8.
	return {"wagons": count, "trading": trading, "gun_groups": [first_guns, gun_pool - first_guns],
		"soldiers": soldiers, "mammoths": mammoths}


static func _debit_casualties(wagons, soldiers: int, mammoths: int) -> void:
	# TEXTEK0x4d10–0x4dcd: no state filter; quantity==24, not TYPE==24.
	# Budget changes ONLY on underflow; a paid budget repeats on later wagons.
	for wagon in wagons.wagons:
		if wagon[Wagons.TYPE] == 7:
			wagon[Wagons.QUANTITY] -= mammoths
			if wagon[Wagons.QUANTITY] < 0:
				mammoths = -wagon[Wagons.QUANTITY]
				wagon[Wagons.QUANTITY] = 0
		elif wagon[Wagons.TYPE] == 23 or wagon[Wagons.QUANTITY] == 24:
			wagon[Wagons.QUANTITY] -= soldiers
			if wagon[Wagons.QUANTITY] < 0:
				soldiers = -wagon[Wagons.QUANTITY]
				wagon[Wagons.QUANTITY] = 0


static func _scrap(wagons, target: int, rng: RandomNumberGenerator) -> Array[int]:
	var destroyed: Array[int] = []
	# TEXTEK0x51d1–0x53fe: eight unrolled calls, stopping at successful target.
	for attempt in 8:
		if destroyed.size() >= target:
			break
		var before: Array = wagons.wagons.duplicate(true)
		Outcome.scrap_wagons(wagons, 1, rng)
		for index in wagons.count():
			if before[index][Wagons.STATE] != 3 and wagons.wagons[index][Wagons.STATE] == 3:
				destroyed.append(index)
	return destroyed


static func _capture(wagons, count: int, rng: RandomNumberGenerator) -> void:
	# Correct automatic-path switch; shared legacy helper mistranslates its base.
	# TEXTEK0x59b0 / opcodes.c cswitch2: index=roll−2, cases0..7.
	for index in count:
		if wagons.count() >= Wagons.MAX_WAGONS:
			break
		var kind := 17 + _rnd(rng, 2)
		var goods := _rnd(rng, 16) + 1
		var capacity := 40
		if goods in [2, 3]:
			capacity = 10
		elif goods in [5, 6, 8, 9]:
			goods = 10 + _rnd(rng, 7)
		var quantity := _rnd(rng, capacity / 2 if kind == 17 else capacity) + 1
		wagons.wagons.append([kind, 0, goods, quantity])
