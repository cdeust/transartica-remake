extends RefCounted
class_name EnemyTrains

# Source: tasks/evidence/enemy-trains.md (YODA 0x2af7 spawn, YODA 0x33fe scheduling,
# TIME 0x1d8b scripted slot, TIME 0x11a6..0x1961 movement, TIME 0x261c/0x28d7
# encounter, YODA 0xa56 removal). Rail turning/curve rules are read-only reuse of
# RailNetwork; this file owns only the enemy-specific table, its own map[0x3080]
# bit-16 presence grid, and the movement/spawn/encounter step. rail_network.gd,
# train_journey.gd and main.gd are not edited by this file (ownership boundary).
const RailNetworkScript = preload("res://scripts/rail_network.gd")

const SLOT_COUNT := 30 # source: main[0x5eb4], 30 records.
const SPAWN_SLOT_LIMIT := 28 # YODA 0x2b17: the free-slot scan stops at slot 28.
const SCRIPTED_SLOT := 29 # TIME 0x1d8b: the only writer of slot 29.
const TABLE_VERSION := 1 # source: authored JSON snapshot schema.

# Record fields, source: tasks/evidence/enemy-trains.md §1/§3.
const STATE := 0
const DX := 1 # stored as x-40, matching the original field.
const Y := 2
const HEADING := 3
const PHASE := 4
const REMAINDER := 5
const SPEED := 6
const STRENGTH := 7
const FIELD_COUNT := 8

# YODA 0x2b42..0x2c9a: 9 spawn points (dx, y, heading), rnd(9) selects one.
const SPAWN_POINTS := [
	[-31, 40, 4], [-28, 40, 6], [-29, 41, 2],
	[75, 25, 6], [72, 25, 8], [73, 26, 4],
	[38, 61, 8], [35, 61, 4], [37, 62, 2],
]

# TIME 0x1d8b/0x1e1b: the scripted slot-29 train and its map cell.
const SCRIPTED_SPAWN_CELL := Vector2i(152, 66)
const SCRIPTED_REMOVE_CELL := Vector2i(151, 66)
const SCRIPTED_MARK_CELL := Vector2i(154, 62)
const SCRIPTED_RECORD := [-1, 114, 62, 2, 0, 0, 0, 19]

const OBSTACLE_TILES := [13, 113, 34, 35, 36, 37, 65, 67, 69, 78, 79, 107, 114, 116, 120] # TIME 0x228c, abs(tile).
const DAMAGED_TRACK_LIMIT := -105 # TIME 0x21ef: -105 < tile < 0 is a wait, not a bounce.
const REVERSE_HEADING := {1: 9, 9: 1, 2: 8, 8: 2, 3: 7, 7: 3, 4: 6, 6: 4, 5: 5} # TIME 0x22db.
const SPEED_CAP := 45 # TIME 0x1316..0x1327, same cap as the player's field.
const REMAINDER_STEP := 23 # TIME 0x134b, same step as RailNetwork/TrainJourney.
const REMAINDER_LIMIT := 22 # TIME 0x1339.
const PHASES_PER_TILE := 3 # TIME 0x1365.
const REMOVED_STATE := 2 # YODA 0xaae: a removed slot never matches the spawn scan.
const DOUBLE_SPEED_TILES := [15, 16] # TIME 0x12aa/0x12d1: reads the player's own heading.

# TIME 0x1444 preamble: history of the player's most recent switch cells, read-only
# mirror of main[0x306c] fed by record_player_position() since rail_network.gd does
# not expose it. Only the two most recent entries are ever consulted (source: the
# preamble loop bound L31b <= L37b with L37b == 1 for positive-strength slots).
const SWITCH_HISTORY_DEPTH := 2

var slots: Array = [] # 30 records, each an Array[int] of FIELD_COUNT.
var _switch_history: Array[Vector2i] = []
var _presence := PackedByteArray() # this file's own mirror of main[0x3080] bit 16.


func _init() -> void:
	reset()


func reset() -> void:
	slots = []
	for _slot in SLOT_COUNT:
		slots.append(_empty_record())
	_switch_history = []
	_presence = PackedByteArray()
	_presence.resize(RailNetworkScript.WIDTH * RailNetworkScript.HEIGHT)


func _empty_record() -> Array:
	var record := []
	record.resize(FIELD_COUNT)
	record.fill(0)
	return record


func cell(slot: int) -> Vector2i:
	return Vector2i(slots[slot][DX] + 40, slots[slot][Y])


func is_active(slot: int) -> bool:
	return slots[slot][STATE] != 0 and slots[slot][STATE] != REMOVED_STATE


## Precondition: rng is seeded by the caller; difficulty is main+0x6539's current
## value (default 0, tasks/evidence/enemy-trains.md §1). Postcondition: at most one
## slot 0..28 gains state 1 with a spawn-point cell and marked map bit; consumes
## rnd(9), then rnd(2), then rnd(6) from rng only when a slot spawns.
func spawn(difficulty: int, rng: RandomNumberGenerator) -> int:
	var slot := _free_slot()
	if slot < 0:
		return -1
	var point: Array = SPAWN_POINTS[rng.randi_range(0, SPAWN_POINTS.size() - 1)]
	var record: Array = slots[slot]
	record[DX] = point[0]
	record[Y] = point[1]
	record[HEADING] = point[2]
	record[STATE] = 1
	record[PHASE] = 2
	record[SPEED] = 20 + slot / 2 + difficulty
	record[STRENGTH] = slot / 2 + difficulty + 1 + rng.randi_range(0, 1) + 20 * rng.randi_range(0, 5)
	_set_bit(cell(slot), true)
	return slot


func _free_slot() -> int:
	for slot in SPAWN_SLOT_LIMIT + 1:
		if slots[slot][STATE] == 0:
			return slot
	return -1


## TIME 0x33fe: at difficulty 4, spawn on every hour where hour % 12 == 0 (checked
## after the hour increment, before the day rollover). Call from main.gd's calendar
## hook; tasks/evidence/enemy-trains.md §6 describes the missing per-hour hook.
func maybe_spawn_on_hour(hour: int, difficulty: int, rng: RandomNumberGenerator) -> int:
	if difficulty == 4 and hour % 12 == 0:
		return spawn(difficulty, rng)
	return -1


## TIME 0x3449..0x346c: at any other difficulty, spawn on day rollover when
## new_day % (4 - difficulty) == 0.
func maybe_spawn_on_day(day: int, difficulty: int, rng: RandomNumberGenerator) -> int:
	if difficulty != 4 and day % (4 - difficulty) == 0:
		return spawn(difficulty, rng)
	return -1


## TIME 0x1d8b: the player committing into (152,66) spawns slot 29 unless it is
## already removed (state == 2); TIME 0x1e1b: the player committing into (151,66)
## clears it. Call once per cycle after the player's TrainJourney.advance() commits.
func sync_scripted_slot(player_cell: Vector2i) -> void:
	if player_cell == SCRIPTED_SPAWN_CELL and slots[SCRIPTED_SLOT][STATE] != REMOVED_STATE:
		slots[SCRIPTED_SLOT] = SCRIPTED_RECORD.duplicate()
		_set_bit(SCRIPTED_MARK_CELL, true)
	elif player_cell == SCRIPTED_REMOVE_CELL:
		_set_bit(SCRIPTED_MARK_CELL, false)
		slots[SCRIPTED_SLOT] = _empty_record()


## YODA 0xa56: called by the combat integration after a resolved encounter.
## Postcondition: the slot's map bit is cleared and fields 1..7 zeroed; state
## becomes REMOVED_STATE and the slot is never reused (tasks/evidence/enemy-trains.md §5).
func remove(slot: int) -> void:
	_set_bit(cell(slot), false)
	var record: Array = slots[slot]
	for field in range(1, FIELD_COUNT):
		record[field] = 0
	record[STATE] = REMOVED_STATE


## Feeds the switch-history mirror (see SWITCH_HISTORY_DEPTH) from the player's
## committed cell for this cycle. Call after TrainJourney.advance() commits.
func record_player_position(player_cell: Vector2i, network: RailNetworkScript) -> void:
	if network.is_switch(player_cell):
		_switch_history.push_front(player_cell)
		if _switch_history.size() > SWITCH_HISTORY_DEPTH:
			_switch_history.resize(SWITCH_HISTORY_DEPTH)


## TIME 0x11a6..0x1961 per-cycle step for every active slot. Precondition: network
## is loaded; rng is seeded by the caller; player_heading is main+0x2fbb (the
## player's current heading), needed only for the tile-15/16 speed quirk (§3).
## Postcondition: each slot's state/phase/remainder/heading/position and this
## file's bit-16 mirror match the decoded rules.
func advance_cycle(network: RailNetworkScript, rng: RandomNumberGenerator, player_heading: int) -> void:
	for slot in SLOT_COUNT:
		_advance_slot(slot, network, rng, player_heading)


func _advance_slot(slot: int, network: RailNetworkScript, rng: RandomNumberGenerator, player_heading: int) -> void:
	var record: Array = slots[slot]
	var state: int = record[STATE]
	if state == 0 or state == REMOVED_STATE:
		return
	if absi(state) > 49: # TIME 0x11dd: unblock, sign-only; no known producer (Pa).
		record[STATE] = signi(state)
		return
	if absi(state) >= 5: # TIME 0x1216..0x1233: wait timer (damaged-track stall).
		record[STATE] = state - 1 if state > 0 else state + 1
		return
	_step_position(record, network, rng, player_heading)


func _step_position(record: Array, network: RailNetworkScript, rng: RandomNumberGenerator, player_heading: int) -> void:
	var speed: int = mini(_effective_speed(record, network, player_heading), SPEED_CAP)
	record[REMAINDER] += speed / 2
	if record[REMAINDER] <= REMAINDER_LIMIT:
		return
	record[REMAINDER] -= REMAINDER_STEP
	record[PHASE] += 1
	if record[PHASE] < PHASES_PER_TILE:
		return
	record[PHASE] = 0
	_commit_candidate(record, network, rng)


# TIME 0x1244..0x1316: field[6] is the speed on every tile. On tile 15/16 the
# original reads the *player's* heading (main+0x2fbb) instead of the mover's own
# field[3] to decide whether the tile doubles the speed -- verified directly in the
# listing and kept as-is rather than "fixed" (tasks/evidence/enemy-trains.md §3).
func _effective_speed(record: Array, network: RailNetworkScript, player_heading: int) -> int:
	var here := Vector2i(record[DX] + 40, record[Y])
	var code := absi(network.tile(here))
	if code in DOUBLE_SPEED_TILES:
		var doubles: bool = (code == 15 and player_heading in [4, 6]) \
				or (code == 16 and player_heading in [2, 8])
		return record[SPEED] * 2 if doubles else record[SPEED]
	return network.progress_speed(here, record[HEADING], record[SPEED])


func _commit_candidate(record: Array, network: RailNetworkScript, rng: RandomNumberGenerator) -> void:
	var here := Vector2i(record[DX] + 40, record[Y])
	var heading: int = _choose_heading(here, record[HEADING], record[STRENGTH], network, rng)
	var candidate: Vector2i = here + network.DELTAS[heading]
	var candidate_code := network.tile(candidate)
	if candidate_code < 0 and candidate_code > DAMAGED_TRACK_LIMIT:
		record[STATE] = 5 * signi(record[STATE]) # TIME 0x2201: wait at damaged track.
		return
	if absi(candidate_code) in OBSTACLE_TILES:
		_bounce(record) # TIME 0x22db/0x2352..0x2384.
		return
	_set_bit(here, false)
	_set_bit(candidate, true)
	record[DX] = candidate.x - 40
	record[Y] = candidate.y
	record[HEADING] = heading


func _bounce(record: Array) -> void:
	record[HEADING] = REVERSE_HEADING.get(record[HEADING], record[HEADING])
	record[STATE] = -record[STATE]
	record[PHASE] = absi(record[PHASE] - 2) - 1
	record[REMAINDER] = REMAINDER_STEP


# TIME 0x1444/0x168c..0x1918: curves and trailing switch entries reuse
# RailNetwork.turn() unchanged. A facing switch entry only differs from the player
# when the mover has not recently stood where the player last set a switch
# (strength < 0, or no match in the two-entry history): then the diverge choice is
# rnd(2) instead of the switch's current position.
func _choose_heading(here: Vector2i, heading: int, strength: int, network: RailNetworkScript, rng: RandomNumberGenerator) -> int:
	var code := absi(network.tile(here))
	var base := code - code % 2
	if not RailNetworkScript.SWITCH_RULES.has(base):
		return network.turn(here, heading)
	var rule: Array = RailNetworkScript.SWITCH_RULES[base]
	if heading != rule[0]: # trailing entry or unrelated heading: deterministic.
		return network.turn(here, heading)
	var follows_player := strength >= 0 and here in _switch_history
	var diverge: bool = network.switch_diverges(here) if follows_player else rng.randi_range(0, 1) == 1
	return rule[1] if diverge else heading


func _set_bit(target: Vector2i, on: bool) -> void:
	if target.x < 0 or target.x >= RailNetworkScript.WIDTH or target.y < 0 or target.y >= RailNetworkScript.HEIGHT:
		return
	_presence[target.x * RailNetworkScript.HEIGHT + target.y] = 1 if on else 0


func has_presence(target: Vector2i) -> bool:
	if target.x < 0 or target.x >= RailNetworkScript.WIDTH or target.y < 0 or target.y >= RailNetworkScript.HEIGHT:
		return false
	return _presence[target.x * RailNetworkScript.HEIGHT + target.y] == 1


## TIME 0x2392..0x261c/0x28d7: the player's candidate cell carries bit 16 -> scan
## slots 0..29 for the matching cell; first match wins. Returns -1 when absent.
func encounter_at(cell_probe: Vector2i) -> int:
	if not has_presence(cell_probe):
		return -1
	for slot in SLOT_COUNT:
		if slots[slot][STATE] != 0 and cell(slot) == cell_probe:
			return slot
	return -1


func snapshot() -> Dictionary:
	return {"version": TABLE_VERSION, "slots": slots.duplicate(true)}


func restore(data: Variant) -> bool:
	if not data is Dictionary or not data.has("version") or not data.has("slots"):
		return false
	if int(data.version) != TABLE_VERSION or not data.slots is Array or data.slots.size() != SLOT_COUNT:
		return false
	var candidate: Array = []
	for record in data.slots:
		if not record is Array or record.size() != FIELD_COUNT:
			return false
		for value in record:
			if not typeof(value) in [TYPE_INT, TYPE_FLOAT]:
				return false
		candidate.append(record.duplicate())
	slots = candidate
	_switch_history = []
	_presence = PackedByteArray()
	_presence.resize(RailNetworkScript.WIDTH * RailNetworkScript.HEIGHT)
	for slot in SLOT_COUNT:
		if is_active(slot):
			_set_bit(cell(slot), true)
	return true
