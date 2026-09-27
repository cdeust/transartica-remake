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

# YODA 0x1f0e "empty/background" neighbour test: value==0 | value>85 | value<-124 | the
# fourth disjunct (value>-107 & value<-113) is unsatisfiable as written (raw operand dump,
# mines.md §3) and is therefore omitted below rather than encoded dead.
const EMPTY_HIGH := 85
const EMPTY_LOW := -124

# YODA 0x200 question presentation (not a rule, kept for the orchestrator's UI wiring).
const QUESTION_ID := 22
const QUESTION_TEXT := 72
const SCENE_CODE := -22

# Corner search order is fixed by the bytecode and grouped by dx, because a neighbour match
# (an EXCLUDED code, i.e. a switch of that family already there) abandons the whole dx group
# without trying its second dy (YODA 0x1fb4/0x2168 jump straight to the outer L0x18b loop,
# mines.md §3). "excluded": placing here is refused when the neighbour already has one of
# these codes -- the site must be free of that switch pair, not already carry one.
# axis "x": neighbour is (x+dx, y); axis "y": neighbour is (x, y+dy).
const CODE2_GROUPS := [
	[
		{"dy": -1, "axis": "x", "excluded": [18, 19], "switch": 20},
		{"dy": 1, "axis": "x", "excluded": [22, 23], "switch": 24},
	],
	[
		{"dy": -1, "axis": "x", "excluded": [20, 21], "switch": 18},
		{"dy": 1, "axis": "x", "excluded": [24, 25], "switch": 22},
	],
]
const CODE3_GROUPS := [
	[
		{"dy": -1, "axis": "y", "excluded": [28, 29], "switch": 32},
		{"dy": 1, "axis": "y", "excluded": [32, 33], "switch": 28},
	],
	[
		{"dy": -1, "axis": "y", "excluded": [26, 27], "switch": 30},
		{"dy": 1, "axis": "y", "excluded": [30, 31], "switch": 26},
	],
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


# YODA 0x1e2c..0x1eb8: 5 off every active mine whose wealth is still positive (0x1e40 guards
# the decrement itself); below 1, the cell becomes 79 once. A slot that has already crossed
# the threshold stays frozen forever -- the guard skips both the decrement and the write on
# every later tick, so this never re-emits a write for an already-depleted slot (mines.md §2).
# Deterministic, no rnd() call in the source. Call only on the day%3==0 rollover
# (game_calendar.gd "mines").
func deplete() -> Dictionary:
	var writes := {}
	for index in SLOT_COUNT:
		var record: Array = records[index]
		if not is_used(record) or record[FIELD_WEALTH] <= 0:
			continue
		record[FIELD_WEALTH] -= DECAY_PER_TICK
		if record[FIELD_WEALTH] < DEPLETED_BELOW:
			writes[mine_cell(record)] = DEPLETED_TILE
	return writes


# YODA 0x1eb9..0x2317: one new mine per rollover, only while a slot is free and day <= 127.
# precondition: day >= 1 (game_calendar.gd never produces 0; field[2] == 0 is the free-slot
# sentinel, so day == 0 would silently create an unfindable slot).
func create(day: int, network, rng: RandomNumberGenerator) -> Dictionary:
	if day > CREATION_DAY_LIMIT:
		return {}
	var slot := find_free_slot()
	if slot < 0:
		return {}
	var cx := rng.randi_range(0, CENTER_X_SPREAD - 1) + CENTER_MIN
	var cy := rng.randi_range(0, CENTER_Y_SPREAD - 1) + CENTER_MIN
	var placement := _search_placement(Vector2i(cx, cy), network)
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


func _search_placement(center: Vector2i, network) -> Dictionary:
	for x in range(center.x - SEARCH_RADIUS, center.x + SEARCH_RADIUS + 1):
		for y in range(center.y - SEARCH_RADIUS, center.y + SEARCH_RADIUS + 1):
			var hit := _match_cell(Vector2i(x, y), network)
			if not hit.is_empty():
				return hit
	return {}


func _match_cell(cell: Vector2i, network) -> Dictionary:
	var code: int = network.tile(cell)
	if code == 2:
		return _match_groups(cell, network, CODE2_GROUPS)
	if code == 3:
		return _match_groups(cell, network, CODE3_GROUPS)
	return {}


func _match_groups(cell: Vector2i, network, groups: Array) -> Dictionary:
	for group_index in groups.size():
		var dx := -1 if group_index == 0 else 1
		var placed := _match_dx_group(cell, dx, network, groups[group_index])
		if not placed.is_empty():
			return placed
	return {}


# One dx group (two dy corners). An excluded-neighbour match abandons the group immediately,
# without trying its second dy -- see the const comment above.
func _match_dx_group(cell: Vector2i, dx: int, network, corners: Array) -> Dictionary:
	for corner in corners:
		var dy: int = corner.dy
		var diagonal := cell + Vector2i(dx, dy)
		if not _is_empty_tile(network.tile(diagonal)):
			continue
		var neighbor: Vector2i = cell + Vector2i(dx, 0) if corner.axis == "x" else cell + Vector2i(0, dy)
		if network.tile(neighbor) in corner.excluded:
			return {}
		return {"switch_cell": cell, "switch_code": corner.switch, "mine_cell": diagonal}
	return {}


static func _is_empty_tile(code: int) -> bool:
	return code == 0 or code > EMPTY_HIGH or code < EMPTY_LOW


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
	if not _is_contiguous(parsed):
		return false
	records = parsed
	return true


# find_free_slot() and create() both stop at the FIRST free slot (YODA 0x1e3c/0x1ea4), and no
# source ever frees a used slot (mines.md §1/§2): a fresh game's occupancy is therefore always
# a contiguous run from slot 0. A used slot after a free one is not a state this table's own
# rules can produce.
func _is_contiguous(parsed: Array) -> bool:
	var seen_free := false
	for entry in parsed:
		if is_used(entry):
			if seen_free:
				return false
		else:
			seen_free = true
	return true


func _valid_record(entry: Variant) -> bool:
	if not entry is Array or entry.size() != 4:
		return false
	for field in entry:
		if not (typeof(field) == TYPE_INT or typeof(field) == TYPE_FLOAT) or float(field) != floor(float(field)):
			return false
	var wealth: int = int(entry[FIELD_WEALTH])
	# mine_cell().x in [0, RailNetwork.WIDTH), so field[FIELD_X] = x - 40 in [-40, 119];
	# field[FIELD_Y] in [0, RailNetwork.HEIGHT). The 0x1e40 guard freezes wealth the first
	# tick it drops below 1, so the only reachable floor is the -5-per-tick undershoot from
	# a base in [40, 49]: -4..0 (or exactly -1 from prospect() YES). Ceiling is rnd(10)+40.
	return int(entry[FIELD_X]) >= -40 and int(entry[FIELD_X]) <= 119 \
			and int(entry[FIELD_Y]) >= 0 and int(entry[FIELD_Y]) <= 72 \
			and wealth >= -4 and wealth <= WEALTH_MIN + WEALTH_SPREAD - 1
