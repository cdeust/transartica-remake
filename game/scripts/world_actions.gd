extends RefCounted

# MIT. Session-owned world effects, YODA mine handlers and TIME pre-entry drill.
# source: tasks/evidence/mines.md, obstacles.md; verified listings 2026-09-30.
const MineTable = preload("res://scripts/mines.gd")
const Management = preload("res://scripts/train_management.gd")

var journey
var wagons
var engine
var trade
var rng: RandomNumberGenerator
var mines = MineTable.new()
var management = Management.new()
var pending_mine := -1
var mine_accepted := false
var last_mine_day := 0
var visited_cities: Array[int] = []


func attach(active_journey, active_wagons, active_engine, active_trade, active_rng: RandomNumberGenerator) -> void:
	journey = active_journey
	wagons = active_wagons
	engine = active_engine
	trade = active_trade
	rng = active_rng
	management.attach(wagons, engine)


# Replay-safe host calendar hook; YODA0x3446 fires only day%3==0.
func tick_mines(day: int) -> bool:
	if day < 1 or day % 3 != 0 or day <= last_mine_day:
		return false
	var before := mines.snapshot()
	var random_before := rng.state
	var writes := mines.tick(day, journey.network, rng)
	if not journey.network.apply_mine_writes(writes):
		mines.restore(before)
		rng.state = random_before
		push_error("MineTable produced invalid map writes on day %d" % day)
		return false
	last_mine_day = day
	return true


func ask_mine(cell: Vector2i) -> Dictionary:
	if journey.network.tile(cell) != MineTable.MINE_TILE:
		return {}
	var slot: int = mines.slot_for_cell(cell)
	if slot < 0:
		return {}
	pending_mine = slot
	mine_accepted = false
	engine.brake = true
	engine.speed = 0
	var record: Array = mines.records[slot]
	return {"question": 22, "text": 72, "ore": "ANTHRACITE" if MineTable.is_anthracite(record) else "LIGNITE",
		"wealth": int(record[MineTable.FIELD_WEALTH]), "year": 2714}


# Answer YES opens the mine scene; YODA0x25c2 delays mutation until close.
func answer_mine(accept: bool) -> bool:
	if pending_mine < 0 or mine_accepted:
		return false
	if not accept:
		pending_mine = -1
		return true
	mine_accepted = true
	return true


func close_mine() -> bool:
	if pending_mine < 0 or not mine_accepted:
		return false
	var before := mines.snapshot()
	var writes := mines.prospect(pending_mine, true)
	if not journey.network.apply_mine_writes(writes):
		mines.restore(before)
		return false
	pending_mine = -1
	mine_accepted = false
	# YODA scene -22 ->0x9ee ->0x18e3; brake remains on.
	journey.reverse_direction()
	engine.speed = 0
	return true


# TIME0x1c31..1c75 runs before the station tile test.
func before_entry(cell: Vector2i) -> bool:
	if cell != Vector2i(32, 67) or journey.network.tile(cell) != 35 or wagons.wagons.is_empty():
		return false
	if wagons.wagons[0][0] != 8 and wagons.wagons[-1][0] != 8:
		return false
	return journey.network.set_campaign_tile(cell, 2)


func visit_city(city: int) -> void:
	# GLIEU0x33 writes negative abs(kind), preserving its kind and first-visit state.
	if not city in visited_cities:
		visited_cities.append(city)


func snapshot() -> Dictionary:
	return {"mines": mines.snapshot(), "last_mine_day": last_mine_day,
		"pending_mine": pending_mine, "mine_accepted": mine_accepted,
		"visited_cities": visited_cities.duplicate()}


func restore(value: Variant) -> bool:
	if not value is Dictionary or not value.get("mine_accepted") is bool or not value.get("visited_cities") is Array:
		return false
	for field in ["last_mine_day", "pending_mine"]:
		if not typeof(value.get(field)) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value[field])) or float(value[field]) != floorf(float(value[field])):
			return false
	if value.last_mine_day < 0 or value.last_mine_day % 3 != 0 or value.pending_mine < -1 or value.pending_mine >= MineTable.SLOT_COUNT:
		return false
	if value.mine_accepted and value.pending_mine < 0:
		return false
	var restored = MineTable.new()
	if not restored.restore(value.get("mines")):
		return false
	if value.pending_mine >= 0 and not MineTable.is_used(restored.records[int(value.pending_mine)]):
		return false
	for record in restored.records:
		if MineTable.is_used(record):
			var expected := 78 if record[MineTable.FIELD_WEALTH] > 0 else 79
			if journey.network.tile(MineTable.mine_cell(record)) != expected:
				return false
	var cities: Array[int] = []
	for city in value.visited_cities:
		if not typeof(city) in [TYPE_INT, TYPE_FLOAT] or float(city) != floorf(float(city)) or city < 0 or city >= 46 or int(city) in cities:
			return false
		cities.append(int(city))
	mines = restored
	last_mine_day = int(value.last_mine_day)
	pending_mine = int(value.pending_mine)
	mine_accepted = value.mine_accepted
	visited_cities = cities
	return true
