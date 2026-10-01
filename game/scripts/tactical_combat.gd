extends RefCounted
signal audio_cue_requested(source_offset: int)
signal presentation_event_requested(event: Dictionary)
signal presentation_tick_started(seconds: float)

# MIT. Domain state for WDECOR33. Offsets refer to the private ECS ALIS listing.
const Setup = preload("res://scripts/combat_setup.gd")
const Actors = preload("res://scripts/tactical_actors.gd")
const Weapons = preload("res://scripts/tactical_weapons.gd")
# WDECOR0x0411 ctiming4; ALIS sys_sdl2.c58,279: 50Hz * multiplier4.
const STEP_SECONDS := 4.0 / 50.0
const CELL := 16 # WDECOR0x00c2; seven rows, four roof cells per64px wagon.
const DIRECTIONS := [Vector2i(0,-1), Vector2i(1,-1), Vector2i(1,0), Vector2i(1,1), Vector2i(0,1), Vector2i(-1,1), Vector2i(-1,0), Vector2i(-1,-1), Vector2i.ZERO]
var trains: Array = [[], []]
var offsets: Array = [0, 0]
var velocities: Array = [0, 0]
var actors: Array = []
var charges: Array = []
var events: Array = []
var rng := RandomNumberGenerator.new()
var aggressiveness := 0
var columns := 80
var scan := 0
var scan_side := 1
var sweep := 0
var ai_wagon := 0
var ai_wait := 0
var ai_direction := 0
var ticks := 0
var next_id := 0
var outcome := 0 # WDECOR byte12: 0 pending,1 win,2 loss.
var settled := false
var original: Array = []
var initial_pools := {}
var remainder := 0.0

func begin(wagons, strength: int, source_rng: RandomNumberGenerator) -> void:
	rng.seed = source_rng.seed
	rng.state = source_rng.state
	original = wagons.wagons.duplicate(true)
	initial_pools = preload("res://scripts/combat_outcome.gd").auto_resolve_pools(wagons)
	trains = [Setup.player_roster(wagons), []]
	var enemy: Dictionary = Setup.enemy_composition(strength, rng)
	aggressiveness = enemy.aggressiveness
	for i in enemy.classes.size():
		trains[1].append({"class": enemy.classes[i], "quantity": enemy.quantities[i], "health": 3})
	for side in 2:
		for wagon in trains[side]:
			wagon.reload = 0
			offsets[side] = trains[side].size() * 64 / 2 - 64 #0x0213,0225.
	columns = clampi((trains[0].size() + trains[1].size()) * 4 + 8, 80, 416)
	# Enemy roof population, WDECOR0x08c8–093b.
	for slot in range(1, trains[1].size() * 4):
		if rnd(400) < aggressiveness:
			add_actor(1, slot, -1, rnd(enemy.b) + 1, false, 1, [2, 6, 8][rnd(3)])
	source_rng.state = rng.state

func rnd(bound: int) -> int:
	if bound <= 0:
		rng.randi()
		return 0
	return rng.randi_range(0, bound - 1)

func train_cell(side: int, wagon: int) -> int:
	#0x109f/40ef: common field coordinates; screen reverses roof-slot indexing.
	return (288 + offsets[side] + center_offset() - wagon * 64) / CELL

func center_offset() -> int:
	return columns * CELL / 2 - 160 #0x0203.

func roof_cell(side: int, x: int) -> int:
	return (offsets[side] + 304 - (x * CELL - center_offset())) / CELL #0x2fcc.

func actor_at(x: int, y: int, roof: int = -1, ignore: int = -1):
	for actor in actors:
		if actor.id == ignore or actor.count <= 0 or actor.roof != roof:
			continue
		var span: int = 2 if actor.mammoth and roof < 0 else 1
		if x >= actor.x and x < actor.x + span and y >= actor.y and y < actor.y + span:
			return actor
	return null

func add_actor(side: int, x: int, y: int, count: int, mammoth: bool, roof: int = -1, direction: int = 8) -> Dictionary:
	var actor := {"id": next_id, "side": side, "x": x, "y": y, "count": count, "mammoth": mammoth, "roof": roof, "direction": direction, "processed": -1}
	next_id += 1
	actors.append(actor)
	return actor

func deploy(side: int, wagon: int, count: int) -> bool:
	if outcome != 0 or side < 0 or side > 1 or wagon < 0 or wagon >= trains[side].size():
		return false
	var car: Dictionary = trains[side][wagon]
	if car.health <= 0 or car.class not in [Setup.BARRACKS, Setup.LIVESTOCK]:
		return false
	var mammoth: bool = car.class == Setup.LIVESTOCK
	var amount := 1 if mammoth and side == 0 else mini(count, car.quantity)
	if amount <= 0 or (not mammoth and amount > 30):
		return false
	var x := train_cell(side, wagon)
	var y := (5 if mammoth else 6) if side == 0 else 0
	if not Actors.free_cells(self, x, y, mammoth):
		return false
	car.quantity -= amount
	add_actor(side, x, y, amount, mammoth, -1, 8 if side == 0 else rnd(3) + 3)
	return true

func command(id: int, direction: int, amount: int = 0) -> bool:
	if outcome != 0 or direction < 0 or direction > 8:
		return false
	for actor in actors:
		if actor.id == id and actor.side == 0 and actor.count > 0:
			return Actors.order(self, actor, direction, amount)
	return false

func fire(wagon: int) -> bool:
	if outcome != 0 or wagon < 0 or wagon >= trains[0].size():
		return false
	var car: Dictionary = trains[0][wagon]
	if car.health <= 0 or car.reload != 0 or car.class not in [Setup.CANNON, Setup.MACHINE_GUN]:
		return false
	car.reload = 23 if car.class == Setup.CANNON else 13 #0x39ed,3a07.
	return true

func plant(id: int, delta: int) -> bool:
	if outcome != 0 or delta not in [-1, 1]:
		return false
	for actor in actors:
		if actor.id == id and actor.side == 0 and actor.roof >= 0 and actor.count > 0:
			var slot: int = actor.x + delta
			if slot <= 0 or slot >= trains[actor.roof].size() * 4 or actor_at(slot, -1, actor.roof) != null:
				return false
			for charge in charges:
				if charge.slot == slot and charge.side == actor.roof:
					return false
			charges.append({"side": actor.roof, "slot": slot, "fuse": 5, "owner": 0}) #0x4674.
			return true
	return false

func advance(delta: float) -> void:
	remainder += delta
	while (remainder >= STEP_SECONDS or is_equal_approx(remainder, STEP_SECONDS)) and outcome == 0:
		remainder -= STEP_SECONDS
		step()

func step() -> void:
	if outcome != 0:
		return
	events.clear()
	presentation_tick_started.emit(STEP_SECONDS)
	ticks += 1
	Weapons.move_trains(self)
	Weapons.enemy_ai(self)
	Weapons.run(self)
	#0x0244,1389: scan max(columns/4,40) cells each tick, not all actors each frame.
	#0x13a1/173e: byte8375 is the pass parity carried by the cell sign (processed
	# marker), not a side; both sides are updated on every pass.
	for cell in maxi(columns / 4, 40):
		var actor = actor_at(scan % columns, scan / columns)
		if actor != null and actor.processed != sweep:
			actor.processed = sweep
			Actors.update(self, actor)
		scan += 1
		if scan >= columns * 7:
			scan = 0
			Actors.roof_sweep(self)
			scan_side = 1 - scan_side
			sweep += 1
	actors = actors.filter(func(actor): return actor.count > 0)
	# Emit each completed tick before the next step clears its event array.
	for event in events:
		presentation_event_requested.emit(event.duplicate(true))
	check_end()

func pools(side: int) -> Dictionary:
	var result := {"soldiers": 0, "mammoths": 0, "guns": 0}
	for car in trains[side]:
		if car.health <= 0:
			continue
		if car.class == Setup.BARRACKS:
			result.soldiers += car.quantity
		elif car.class == Setup.LIVESTOCK:
			result.mammoths += car.quantity
		elif car.class in [Setup.CANNON, Setup.MACHINE_GUN]:
			result.guns += 1
	for actor in actors:
		if actor.side == side and actor.count > 0:
			result["mammoths" if actor.mammoth else "soldiers"] += actor.count
	return result

func check_end() -> void:
	var enemy := pools(1)
	var player := pools(0)
	if enemy.guns <= 0 and enemy.soldiers + enemy.mammoths <= 0:
		outcome = 1 #0x0f09 win is checked first.
	elif player.soldiers + player.mammoths <= 0:
		outcome = 2
	for car in trains[0]:
		if car.class in Setup.VITAL_CLASSES and car.health <= 0:
			outcome = 2

func snapshot() -> Dictionary:
	var data := {}
	for key in ["trains", "offsets", "velocities", "actors", "charges", "aggressiveness", "columns", "scan", "scan_side", "sweep", "ai_wagon", "ai_wait", "ai_direction", "ticks", "next_id", "outcome", "settled", "original", "initial_pools", "remainder"]:
		data[key] = get(key)
	data.version = 1
	data.seed = str(rng.seed)
	data.state = str(rng.state)
	return data.duplicate(true)

func restore(data: Variant) -> bool:
	if not preload("res://scripts/tactical_restore.gd").valid(data):
		return false
	for key in snapshot():
		if key not in ["version", "seed", "state"]:
			set(key, data[key] if key == "remainder" else preload("res://scripts/tactical_restore.gd").normalize(data[key]))
	rng.seed = int(data.seed)
	rng.state = int(data.state)
	return true
