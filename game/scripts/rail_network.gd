extends RefCounted
class_name RailNetwork

# Source: tasks/evidence/rail-network.md (TIME 0x1444..0x1918, 0x2392..0x257e,
# TABLE 0x12ea..0x137c, CARTE 0x123f..0x1270). Tiles are signed CARTE.FIC bytes.
const WIDTH := 160 # source: FORMAT-CARTE.md
const HEIGHT := 73 # source: FORMAT-CARTE.md
const NETWORK_VERSION := 1 # source: authored JSON snapshot schema.

# TIME 0x1a34: numeric-keypad headings, y grows southward.
const DELTAS := {
	1: Vector2i(-1, 1), 2: Vector2i(0, 1), 3: Vector2i(1, 1),
	4: Vector2i(-1, 0), 5: Vector2i(0, 0), 6: Vector2i(1, 0),
	7: Vector2i(-1, -1), 8: Vector2i(0, -1), 9: Vector2i(1, -1),
}
# TIME 0x14c9 case bodies: incoming heading -> outgoing heading.
const CURVE_RULES := [
	{6: 3, 7: 4}, {9: 6, 4: 1}, {3: 6, 4: 7}, {6: 9, 1: 4},
	{8: 7, 3: 2}, {8: 9, 1: 2}, {2: 1, 9: 8}, {2: 3, 7: 8},
]
const CURVE_TILES := {
	6: 0, 42: 0, 51: 0, 7: 1, 43: 1, 57: 1, 8: 2, 45: 2, 9: 3, 44: 3,
	10: 4, 47: 4, 11: 5, 46: 5, 12: 6, 55: 6, 13: 7, 48: 7,
}
# TIME 0x168c..0x1913: even base -> [facing heading, diverging heading, trailing heading, trailing result].
const SWITCH_RULES := {
	18: [6, 9, 1, 4], 20: [4, 7, 3, 6], 22: [6, 3, 7, 4], 24: [4, 1, 9, 6],
	26: [2, 3, 7, 8], 28: [2, 1, 9, 8], 30: [8, 9, 1, 2], 32: [8, 7, 3, 2],
}
# TABLE 0x12ea..0x137c bridge writes are not ported: only the debug "super scenar"
# case of TABLE 0x060c reaches them (tasks/evidence/obstacles-unknowns.md §6).
# TIME 0x243a cswitch1 values: event routines not yet ported.
const EVENT_TILES := [-120, 34, 35, 36, 37, 65, 78, 79] # 67, 69, 114, -116: see OBSTACLE_REASON.
# TIME 0x1b9d..0x2044: player-train story cells whose handlers are not yet ported.
const STORY_CELLS := [
	Vector2i(11, 10), Vector2i(28, 67), Vector2i(29, 67), Vector2i(30, 67),
	Vector2i(151, 66), Vector2i(152, 66), Vector2i(152, 48),
]
const TrackWorks = preload("res://scripts/track_works.gd")
const OBSTACLE_REASON := "obstacle" # crevasse, lake or destroyed track: YODA 0x2390 works.
# Not in the TIME 0x243a switch, so TIME lets the train pass; YODA writes them as the
# repaired lake bridges (tasks/evidence/obstacles.md). Other codes <= -105 stay a frontier.
const INTACT_LAKE_BRIDGES := [-121, -117]
const TIMED_BRIDGE := Vector2i(110, 33) # CARTE.FIC -120; YODA toggles it by the hour.
const TIMED_BRIDGE_OPEN := -121
const TIMED_BRIDGE_CLOSED := -120
const REVERSAL_EVENTS := [-120, 65, 78] # source: YODA scenes -5/-22 close through 0x864/0x9ee.
const SPECIAL_TILE_LIMIT := -105 # source: TIME 0x2401 blocks only -105 < tile < 0.
# TIME 0x26fb..0x27b0: fixed station results checked before the city search.
# Negative results -2..-4 also write one map cell (TIME 0x270f, 0x273a, 0x2765).
# Those writes are left out with their unported message 22..24 handlers, and
# restore() only accepts switch toggles as map changes.
const STATION_SPECIALS := {
	Vector2i(23, 67): -2, Vector2i(35, 4): -3, Vector2i(53, 32): -4,
	Vector2i(148, 60): -5, Vector2i(51, 47): 40,
}
const STATION_SEARCH_MAX_Y := 72 # source: TIME 0x27bb compares y + dy < 72, not the map height.
# TIME 0x2818 cswitch2: city tile -> offset added to the search loop counters.
const CITY_TILE_OFFSETS := {
	71: Vector2i(2, 1), 72: Vector2i(1, 1), 73: Vector2i(0, 1),
	74: Vector2i(2, 0), 75: Vector2i(1, 0), 76: Vector2i(0, 0),
}

# source: TIME 0x1c31..0x1d8a,0x270f..0x2765; YODA/CARTE campaign writes.
const CAMPAIGN_WRITES := {
	Vector2i(32, 67): [2], Vector2i(28, 67): [54], Vector2i(29, 67): [-114],
	Vector2i(30, 67): [-113], Vector2i(39, 32): [2], Vector2i(157, 68): [3],
	Vector2i(22, 67): [-122], Vector2i(34, 4): [80], Vector2i(52, 32): [-123],
}

var _initial := PackedInt32Array()
var _tiles := PackedInt32Array()
var _city_anchors: Array[Vector2i] = [] # VILLE.FIC order; anchor_x = signed(field0) + 40.


func load_bytes(map_bytes: PackedByteArray) -> bool:
	if map_bytes.size() != WIDTH * HEIGHT:
		return false
	_initial.resize(map_bytes.size())
	for index in map_bytes.size():
		var value := int(map_bytes[index])
		_initial[index] = value - 256 if value > 127 else value
	_tiles = _initial.duplicate()
	return true


func is_loaded() -> bool:
	return _tiles.size() == WIDTH * HEIGHT


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT


func tile(cell: Vector2i) -> int:
	if not is_loaded() or not in_bounds(cell):
		return 0
	return _tiles[cell.x * HEIGHT + cell.y]


static func is_switch_code(code: int) -> bool:
	return code > 17 and code < 34 # source: CARTE 0x123f on the signed tile.


func is_switch(cell: Vector2i) -> bool:
	return is_switch_code(tile(cell))


func switch_diverges(cell: Vector2i) -> bool:
	return is_switch(cell) and tile(cell) % 2 == 1


func toggle_switch(cell: Vector2i) -> bool:
	# CARTE 0x1253..0x1270: even +1, odd -1.
	if not is_switch(cell):
		return false
	var code := tile(cell)
	_tiles[cell.x * HEIGHT + cell.y] = code + 1 if code % 2 == 0 else code - 1
	return true


func turn(cell: Vector2i, heading: int) -> int:
	var code := absi(tile(cell))
	if CURVE_TILES.has(code):
		return CURVE_RULES[CURVE_TILES[code]].get(heading, heading)
	var base := code - code % 2
	if SWITCH_RULES.has(base):
		var rule: Array = SWITCH_RULES[base]
		if heading == rule[0]:
			return rule[1] if code % 2 == 1 else heading
		if heading == rule[2]:
			return rule[3]
	return heading


func progress_speed(cell: Vector2i, heading: int, speed: int) -> int:
	# TIME 0x0486..0x0560.
	var code := absi(tile(cell))
	var doubled := (code == 15 and heading in [4, 6]) or (code == 16 and heading in [2, 8]) \
		or (code >= 38 and code <= 52) or (code >= 55 and code <= 57)
	return speed * 2 if doubled else speed


# Returns "" when the move is a plain ported step, otherwise the boundary reason.
func entry_boundary(candidate: Vector2i) -> String:
	if not in_bounds(candidate):
		return "world edge wrap not verified"
	var code := tile(candidate)
	if not TrackWorks.kind_for(code).is_empty():
		return OBSTACLE_REASON
	if code in EVENT_TILES:
		return "station" if code >= 34 and code <= 37 else "event site"
	if code <= SPECIAL_TILE_LIMIT and not code in INTACT_LAKE_BRIDGES:
		return "special site"
	if candidate in STORY_CELLS:
		return "story trigger"
	if code == 0:
		return "no track"
	return ""


func set_city_anchors(anchors: Array[Vector2i]) -> void:
	_city_anchors = anchors.duplicate()


# TIME 0x26fb: result for a refused station cell (tiles 34..37).
# >= 0: VILLE.FIC index (message 76); -1: station without city (message 34);
# -2..-5: fixed story stations (messages 22..25).
# TIME 0x2392 tests x 24..38, y 1..7 against table main+0x64fa first; the only
# station tile in that rectangle, (35, 4), is a fixed special here anyway.
func station_lookup(cell: Vector2i) -> int:
	if STATION_SPECIALS.has(cell):
		return STATION_SPECIALS[cell]
	# Offsets are added to the loop counters themselves (TIME 0x283a..0x2868),
	# so a failed record search continues from the shifted counters.
	var dx := -1
	while true:
		var dy := -1
		while true:
			var probe := cell + Vector2i(dx, dy)
			if probe.y < STATION_SEARCH_MAX_Y and probe.y >= 0 and probe.x < WIDTH and probe.x >= 0:
				var code := tile(probe)
				if code > 70 and code < 77:
					var offset: Vector2i = CITY_TILE_OFFSETS[code]
					dx += offset.x
					dy += offset.y
					var anchor := cell + Vector2i(dx, dy)
					for index in mini(_city_anchors.size(), 46):
						if _city_anchors[index] == anchor:
							return index
			dy += 1
			if dy > 1:
				break
		dx += 1
		if dx > 1:
			break
	return -1


# YODA 0x33c7/0x33eb: the calendar opens (-121) and closes (-120) the (110,33) bridge.
func set_timed_bridge(code: int) -> bool:
	if not code in [TIMED_BRIDGE_OPEN, TIMED_BRIDGE_CLOSED]:
		return false
	_tiles[TIMED_BRIDGE.x * HEIGHT + TIMED_BRIDGE.y] = code
	return true


# YODA 0x2390 success: the blocked cell becomes passable track.
func repair(cell: Vector2i) -> bool:
	if not in_bounds(cell) or TrackWorks.kind_for(tile(cell)).is_empty():
		return false
	_tiles[cell.x * HEIGHT + cell.y] = TrackWorks.repaired_code(tile(cell))
	return true


# YODA 0x1e2a..0x2317,0x25e2: exact MineTable outputs; atomic validation.
func apply_mine_writes(writes: Dictionary) -> bool:
	for cell in writes:
		if not cell is Vector2i or not in_bounds(cell) or not _mine_transition(tile(cell), int(writes[cell])):
			return false
	for cell in writes:
		_tiles[cell.x * HEIGHT + cell.y] = int(writes[cell])
	return true


func _mine_transition(before: int, after: int) -> bool:
	if before == 2:
		return after in [18, 20, 22, 24]
	if before == 3:
		return after in [26, 28, 30, 32]
	if before == 78:
		return after == 79
	return (before == 0 or before > 85 or before < -124) and after == 78


# Verified campaign pre-entry effects and CARTE sabotage; caller owns flags.
func set_campaign_tile(cell: Vector2i, code: int) -> bool:
	if not in_bounds(cell) or not _campaign_transition(cell, tile(cell), code):
		return false
	_tiles[cell.x * HEIGHT + cell.y] = code
	return true


func _campaign_transition(cell: Vector2i, before: int, after: int) -> bool:
	if CAMPAIGN_WRITES.has(cell) and after in CAMPAIGN_WRITES[cell]:
		return true
	# CARTE0x27a4: central target revealed by a spy in x64..66,y19..21.
	if cell.x >= 63 and cell.x <= 66 and cell.y >= 19 and cell.y <= 21 and after == -124:
		return true
	# TIME0x1d15/MAIN0x7b3: private region records reveal concealed rails.
	if before == -115 and after >= -128 and after <= 127:
		return true
	# CARTE0x27a4: dynamite destroys ordinary rail and constructed bridges.
	if before >= 1 and before <= 58 and not before in [34, 35, 36, 37]:
		return after == -before
	return {63: 67, 64: 69, -117: 114, -121: -116}.get(before, 0) == after and after != 0


func changed_cells() -> Dictionary:
	var result := {}
	for index in _tiles.size():
		if _tiles[index] != _initial[index]:
			result["%d,%d" % [index / HEIGHT, index % HEIGHT]] = _tiles[index]
	return result


func snapshot() -> Dictionary:
	return {"version": NETWORK_VERSION, "switches": changed_cells()}


func restore(data: Variant) -> bool:
	if not is_loaded() or not data is Dictionary or not data.has("version") or not data.has("switches"):
		return false
	if not data.switches is Dictionary or int(data.version) != NETWORK_VERSION:
		return false
	var candidate := _initial.duplicate()
	for key in data.switches:
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			return false
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		var value: Variant = data.switches[key]
		if not in_bounds(cell) or not (typeof(value) in [TYPE_INT, TYPE_FLOAT]):
			return false
		var original := _initial[cell.x * HEIGHT + cell.y]
		if not is_finite(float(value)) or float(value) != floorf(float(value)) or not _is_saved_change(cell, original, int(value)):
			return false
		candidate[cell.x * HEIGHT + cell.y] = int(value)
	_tiles = candidate
	return true


# A saved map may differ from the initial map by a toggled switch or a repaired obstacle.
func _is_saved_change(cell: Vector2i, original: int, value: int) -> bool:
	if original == value or _campaign_transition(cell, original, value) or _mine_transition(original, value):
		return true
	if (original == 0 or original > 85 or original < -124) and value == 79:
		return true # source: mine creation then depletion/prospecting.
	# source: new mine switches may subsequently toggle or be dynamited.
	if original in [2, 3] and absi(value) >= 18 and absi(value) <= 33:
		var base := absi(value) - absi(value) % 2
		return base in ([18, 20, 22, 24] if original == 2 else [26, 28, 30, 32])
	if original == TIMED_BRIDGE_CLOSED and value == TIMED_BRIDGE_OPEN:
		return true
	if not TrackWorks.kind_for(original).is_empty():
		return value == TrackWorks.repaired_code(original)
	return is_switch_code(original) and absi(value - original) == 1 and is_switch_code(value) \
			and value - value % 2 == original - original % 2


func reset() -> void:
	_tiles = _initial.duplicate()
