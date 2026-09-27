extends RefCounted
class_name MineTable

# Mine table main[0x6082]: creation, day%3==0 depletion, prospect YES/NO.
# Source: tasks/evidence/mines.md (YODA 0x1e2a..0x2317, 0x200..0x25e2; TABLE 0xe7..0x112;
# TIME 0x2509). Pure rules only: no map is owned here, callers apply the returned writes
# to their own RailNetwork instance.

# TABLE 0xe7 zero-fills 50 rows, but YODA 0x1ead only ever loops slots 0..35; rows 36..49
# are dead capacity in the original game (tasks/evidence/mines.md §1).
const SLOT_COUNT := 36
const TABLE_ROWS := 50 # TIME 0x2509 scans the full 50 rows when resolving a cell to a slot.

const FIELD_X := 0 # mine-cell x - 40 (YODA 0x22a1)
const FIELD_Y := 1 # mine-cell y (YODA 0x22b8)
const FIELD_SIGNED_DAY := 2 # +-day of creation; 0 means the slot is free (YODA 0x1e31)
const FIELD_WEALTH := 3 # "wealth index", TEXTEK 0x1675 (YODA 0x22f7)

const DECAY_PER_TICK := 5 # YODA 0x1e52
const DEPLETED_BELOW := 1 # YODA 0x1e5f
const CREATION_DAY_LIMIT := 127 # YODA 0x1eb9
const MINE_TILE := 78
const DEPLETED_TILE := 79
const WEALTH_MIN := 40 # rnd(10) + 40, YODA 0x22f7
const WEALTH_SPREAD := 10

const SEARCH_RADIUS := 10 # YODA 0x1ee8..0x227d: 21x21 window
const CENTER_X_SPREAD := 138 # rnd(138) + 11, YODA 0x1ec7
const CENTER_Y_SPREAD := 50 # rnd(50) + 11, YODA 0x1ed3
const CENTER_MIN := 11

# YODA 0x1f0e "empty/background" neighbour test.
const EMPTY_HIGH := 85
const EMPTY_LOW := -124
const EMPTY_BAND_LOW := -113
const EMPTY_BAND_HIGH := -107

# YODA 0x200 question presentation (not a rule, kept for the orchestrator's UI wiring).
const QUESTION_ID := 22
const QUESTION_TEXT := 72
const SCENE_CODE := -22

# Corner search order is fixed by the bytecode: (-1,-1), (-1,1), (1,-1), (1,1).
# axis "x": neighbour is (x+dx, y); axis "y": neighbour is (x, y+dy). YODA 0x1f8e../0x2142..
const CODE2_CORNERS := [
	{"dx": -1, "dy": -1, "axis": "x", "neighbor": [18, 19], "switch": 20},
	{"dx": -1, "dy": 1, "axis": "x", "neighbor": [22, 23], "switch": 24},
	{"dx": 1, "dy": -1, "axis": "x", "neighbor": [20, 21], "switch": 18},
	{"dx": 1, "dy": 1, "axis": "x", "neighbor": [24, 25], "switch": 22},
]
const CODE3_CORNERS := [
	{"dx": -1, "dy": -1, "axis": "y", "neighbor": [28, 29], "switch": 32},
	{"dx": -1, "dy": 1, "axis": "y", "neighbor": [32, 33], "switch": 28},
	{"dx": 1, "dy": -1, "axis": "y", "neighbor": [26, 27], "switch": 30},
	{"dx": 1, "dy": 1, "axis": "y", "neighbor": [30, 31], "switch": 26},
]

var records: Array = []


func _init() -> void:
	reset()


func reset() -> void:
	records = []
	for _index in SLOT_COUNT:
		records.append([0, 0, 0, 0])


static func is_used(record: Array) -> bool:
	return record[FIELD_SIGNED_DAY] != 0


static func is_anthracite(record: Array) -> bool:
	return record[FIELD_SIGNED_DAY] < 0


static func mine_cell(record: Array) -> Vector2i:
	return Vector2i(record[FIELD_X] + 40, record[FIELD_Y])


func find_free_slot() -> int:
	for index in SLOT_COUNT:
		if not is_used(records[index]):
			return index
	return -1


# TIME 0x2509: full 50-row scan by cell, independent of the 0..35 slots this table manages.
func slot_for_cell(cell: Vector2i) -> int:
	for index in mini(records.size(), TABLE_ROWS):
		var record: Array = records[index]
		if is_used(record) and mine_cell(record) == cell:
			return index
	return -1


# YODA 0x1e2c..0x1eb8: 5 off every active mine; below 1, the cell becomes 79. Deterministic,
# no rnd() call in the source. Call only on the day%3==0 rollover (game_calendar.gd "mines").
func deplete() -> Dictionary:
	var writes := {}
	for index in SLOT_COUNT:
		var record: Array = records[index]
		if not is_used(record):
			continue
		record[FIELD_WEALTH] -= DECAY_PER_TICK
		if record[FIELD_WEALTH] < DEPLETED_BELOW:
			writes[mine_cell(record)] = DEPLETED_TILE
	return writes


# YODA 0x1eb9..0x2317: one new mine per rollover, only while a slot is free and day <= 127.
func create(day: int, network, rng: RandomNumberGenerator) -> Dictionary:
	if day > CREATION_DAY_LIMIT:
		return {}
	var slot := find_free_slot()
	if slot < 0:
		return {}
	var cx := rng.randi_range(0, CENTER_X_SPREAD - 1) + CENTER_MIN
	var cy := rng.randi_range(0, CENTER_Y_SPREAD - 1) + CENTER_MIN
	var placement := _search_placement(cx, cy, network)
	if placement.is_empty():
		return {}
	var anthracite := rng.randi_range(0, 1) == 0
	var wealth := rng.randi_range(0, WEALTH_SPREAD - 1) + WEALTH_MIN
	var mine_at: Vector2i = placement.mine_cell
	records[slot] = [mine_at.x - 40, mine_at.y, -day if anthracite else day, wealth]
	return {placement.switch_cell: placement.switch_code, mine_at: MINE_TILE}


# One day%3==0 rollover: deplete() first (YODA 0x1e2c), then create() (YODA 0x1eb9), matching
# the fixed order of the decoded routine. Combines their map writes for the caller.
func tick(day: int, network, rng: RandomNumberGenerator) -> Dictionary:
	var writes := deplete()
	writes.merge(create(day, network, rng), true)
	return writes


# YODA 0x200..0x25e2/0x2599: prospect answer for an active mine at `slot`.
func prospect(slot: int, accept: bool) -> Dictionary:
	if slot < 0 or slot >= SLOT_COUNT or not is_used(records[slot]):
		return {}
	if not accept:
		return {}
	var record: Array = records[slot]
	record[FIELD_WEALTH] = -1
	return {mine_cell(record): DEPLETED_TILE}


func _search_placement(cx: int, cy: int, network) -> Dictionary:
	for x in range(cx - SEARCH_RADIUS, cx + SEARCH_RADIUS + 1):
		for y in range(cy - SEARCH_RADIUS, cy + SEARCH_RADIUS + 1):
			var hit := _match_cell(x, y, network)
			if not hit.is_empty():
				return hit
	return {}


func _match_cell(x: int, y: int, network) -> Dictionary:
	var code: int = network.tile(Vector2i(x, y))
	if code == 2:
		return _match_corners(x, y, network, CODE2_CORNERS)
	if code == 3:
		return _match_corners(x, y, network, CODE3_CORNERS)
	return {}


func _match_corners(x: int, y: int, network, corners: Array) -> Dictionary:
	for corner in corners:
		var diagonal := Vector2i(x + corner.dx, y + corner.dy)
		if not _is_empty_tile(network.tile(diagonal)):
			continue
		var neighbor := Vector2i(x + corner.dx, y) if corner.axis == "x" else Vector2i(x, y + corner.dy)
		if network.tile(neighbor) in corner.neighbor:
			return {"switch_cell": Vector2i(x, y), "switch_code": corner.switch, "mine_cell": diagonal}
	return {}


static func _is_empty_tile(code: int) -> bool:
	if code == 0 or code > EMPTY_HIGH or code < EMPTY_LOW:
		return true
	return code > EMPTY_BAND_LOW and code < EMPTY_BAND_HIGH


func snapshot() -> Array:
	return records.duplicate(true)


func restore(value: Variant) -> bool:
	if not value is Array or value.size() != SLOT_COUNT:
		return false
	var parsed: Array = []
	for entry in value:
		if not _valid_record(entry):
			return false
		parsed.append((entry as Array).duplicate())
	records = parsed
	return true


func _valid_record(entry: Variant) -> bool:
	if not entry is Array or entry.size() != 4:
		return false
	for field in entry:
		if not (typeof(field) == TYPE_INT or typeof(field) == TYPE_FLOAT) or float(field) != floor(float(field)):
			return false
	var wealth: int = int(entry[FIELD_WEALTH])
	# mine_cell().x in [0, RailNetwork.WIDTH), so field[FIELD_X] = x - 40 in [-40, 119];
	# field[FIELD_Y] in [0, RailNetwork.HEIGHT). No source resets a depleted slot, so
	# deplete() keeps subtracting DECAY_PER_TICK forever (mines.md §1/§2): wealth has no
	# decoded lower bound, only the rnd(10)+40 creation ceiling.
	return int(entry[FIELD_X]) >= -40 and int(entry[FIELD_X]) <= 119 \
			and int(entry[FIELD_Y]) >= 0 and int(entry[FIELD_Y]) <= 72 \
			and wealth <= WEALTH_MIN + WEALTH_SPREAD - 1
