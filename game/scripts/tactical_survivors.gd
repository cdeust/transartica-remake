extends RefCounted
# MIT. WDECOR0957..09c6 stocks;0d90..0dc7 losses;5de8..6067 writeback.
const Setup = preload("res://scripts/combat_setup.gd")
const Wagons = preload("res://scripts/train_wagons.gd")

static func damage_actor(state, actor: Dictionary, before_count: int) -> void:
	var lost: int = before_count-actor.count
	if lost <= 0: return
	state.army_strength[actor.side] -= lost #0da3..0dc7: side-specific army count.
	if actor.side != 0: return
	state.survivors.soldiers -= lost #0da3..0dc7 includes bare mounted strength1.
	if actor.mammoth and before_count > 0 and actor.count <= 0:
		state.survivors.mammoths -= 1 #0d90..0da3: one beast, not actor strength.

static func destroy_wagon(state, car: Dictionary, side: int) -> void:
	if car.class not in [Setup.BARRACKS,Setup.LIVESTOCK]: return
	state.army_strength[side] -= car.quantity #0b66/0b86 and0c86: troops aboard.
	if side != 0: return
	if car.class == Setup.BARRACKS:
		state.survivors.soldiers -= car.quantity #0b86..0b96
	elif car.class == Setup.LIVESTOCK:
		state.survivors.mammoths -= car.quantity #0b66..0b76

static func legacy(data: Dictionary) -> Dictionary:
	# Mounted history cannot recover persistent rider losses from actor strength.
	if data.initial_pools.mammoths != 0: return {}
	var soldiers := 0
	for car in data.trains[0]:
		if car.health > 0 and car.class == Setup.BARRACKS: soldiers += int(car.quantity)
	for actor in data.actors:
		if actor.side != 0: continue
		if actor.mammoth: return {}
		soldiers += int(actor.count)
	return {"soldiers":soldiers,"mammoths":0}

static func army(data: Dictionary) -> Array:
	var strengths := [0,0]
	for side in 2:
		for car in data.trains[side]:
			# JSON numbers are floats before restore normalization; Array.has is typed.
			if car.health > 0 and int(car.class) in [Setup.BARRACKS,Setup.LIVESTOCK]:
				strengths[side] += int(car.quantity)
	for actor in data.actors:
		strengths[int(actor.side)] += int(actor.count)
	return strengths

static func redistribute(state, wagons) -> void:
	for kind in ["soldiers","mammoths"]:
		var remaining: int = state.survivors[kind]
		for car in wagons.wagons:
			if car[Wagons.STATE] != 3 and _capacity(car,kind) > 0:
				remaining -= car[Wagons.QUANTITY] #5df5..5e26 /5f79..5f9b
		for car in wagons.wagons:
			var capacity := _capacity(car,kind)
			if car[Wagons.STATE] == 3 or capacity <= 0 or capacity <= car[Wagons.QUANTITY]: continue
			var take: int = mini(capacity-car[Wagons.QUANTITY],remaining)
			# ALIS amaintc/addnames.c157..162, mem.c182..185: signed byte add.
			car[Wagons.QUANTITY] = ((car[Wagons.QUANTITY]+take+128)&255)-128
			remaining -= take
			if remaining == 0: break
		state.survivors[kind] -= remaining #5f65 /6053: overflow becomes loss.

static func _capacity(car: Array, kind: String) -> int:
	if kind == "soldiers":
		if car[Wagons.TYPE] == Setup.TYPE_BARRACKS: return 50 # source: WDECOR0x5e72.
		if car[Wagons.TYPE] == Setup.TYPE_XL_BARRACKS: return 100 # source: WDECOR0x5eee.
	elif car[Wagons.TYPE] == Setup.TYPE_LIVESTOCK: return 5 # source: WDECOR0x5fd3.
	return 0
