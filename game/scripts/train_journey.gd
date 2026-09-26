extends RefCounted
class_name TrainJourney

const RailNetworkScript = preload("res://scripts/rail_network.gd")
const TrainPathScript = preload("res://scripts/train_path.gd")

# Source: tasks/evidence/rail-network.md, TIME 0x0486..0x067d and TABLE 0x0708/0x0714..0x0732.
# Movement follows the decoded heading rules on the whole network; unported
# station, event, story and edge cells stop the train before entry.
const START_POSITION := Vector2i(12, 62) # source: original TABLE initialization.
const START_HEADING := 6 # source: original TABLE initialization; TIME maps 6 to east.
const MAX_PROGRESS_SPEED := 450 # source: TIME 0x0567..0x0575.
const DISTANCE_STEP := 23 # source: TIME 0x0588..0x059b.
const MAX_DISTANCE_REMAINDER := 22 # source: TIME uses strict remainder >22.
const PHASES_PER_TILE := 3 # source: TIME 0x05a6 commits on phase 3.
const TURN_PHASE := 1 # source: TIME 0x14bd applies heading rules only on phase 1.
const JOURNEY_VERSION := 3 # source: authored JSON snapshot schema.
const HEADING_NAMES := {1: "SOUTH-WEST", 2: "SOUTH", 3: "SOUTH-EAST", 4: "WEST", 6: "EAST", 7: "NORTH-WEST", 8: "NORTH", 9: "NORTH-EAST"}

var network # RailNetwork, assigned by the owner of the world data.
var position := START_POSITION
var heading := START_HEADING
var distance_ticks := 0
var phase := 0
var blocked := false
var stop_reason := ""
var _path = TrainPathScript.new()
var incoming_heading := START_HEADING
var _path_cell := Vector2i(-1, -1)


func advance(speed: int) -> void:
	if blocked or speed <= 0 or network == null or not network.is_loaded():
		return
	_ensure_path()
	var progress: int = mini(network.progress_speed(position, heading, speed), MAX_PROGRESS_SPEED)
	distance_ticks += progress / 20
	if distance_ticks <= MAX_DISTANCE_REMAINDER:
		return
	distance_ticks -= DISTANCE_STEP
	phase += 1
	if phase < PHASES_PER_TILE:
		if phase == TURN_PHASE:
			heading = network.turn(position, heading)
		return
	var candidate: Vector2i = position + network.DELTAS[heading]
	var reason: String = network.entry_boundary(candidate)
	if reason.is_empty():
		_path.append_tile(position, incoming_heading, heading)
		position = candidate
		incoming_heading = heading
		_path_cell = position
		phase = 0
		return
	# TIME 0x063f keeps phase 2 while the entry is refused; the remake stops at
	# this port boundary instead of running the unported handler.
	phase = PHASES_PER_TILE - 1
	distance_ticks = 0
	blocked = true
	stop_reason = reason


func heading_name() -> String:
	return HEADING_NAMES.get(heading, "STOPPED")


func next_cell() -> Vector2i:
	return position + RailNetworkScript.DELTAS.get(heading, Vector2i.ZERO)


# Presentation adaptation: rail_glyphs.gd draws half-tile ports joined at centers.
# TIME phases remain unchanged: phase 1 selects the outgoing rail, before the
# head reaches the center. The head crosses each cell at a constant rate over
# its three phases instead of the entry half in one phase and the exit in two.
func fractional_position() -> Vector2:
	_ensure_path()
	var center := Vector2(position)
	if blocked:
		return center + Vector2(RailNetworkScript.DELTAS[heading]) * 0.5
	var elapsed := _cell_fraction()
	if elapsed < 0.5:
		if incoming_heading == 0:
			return center
		return center - Vector2(RailNetworkScript.DELTAS[incoming_heading]) * (0.5 - elapsed)
	return center + Vector2(RailNetworkScript.DELTAS[heading]) * (elapsed - 0.5)


func _cell_fraction() -> float:
	return float(phase * DISTANCE_STEP + distance_ticks) / float(PHASES_PER_TILE * DISTANCE_STEP)


func _past_center() -> bool:
	return blocked or _cell_fraction() >= 0.5


# Distances are Euclidean map-cell units, before the renderer projects to pixels.
# Missing history is explicit; callers must not extrapolate off the known rails.
func sample_behind(distance_world: float) -> Dictionary:
	var head := fractional_position()
	if not is_finite(distance_world) or distance_world < 0.0:
		return {"ok": false, "reason": "invalid distance"}
	var entry := _entry_position()
	var current := PackedVector2Array([entry])
	var past_center := _past_center()
	if past_center:
		current.append(Vector2(position))
	current.append(head)
	return _path.sample(distance_world, current, heading if past_center else incoming_heading)


# Monotonic arc coordinate during a journey; reset/restore are discontinuities.
# The initial connected tail contributes a constant offset.
func distance_travelled() -> float:
	var head := fractional_position()
	var entry := _entry_position()
	if not _past_center():
		return _path.length + entry.distance_to(head)
	return _path.length + entry.distance_to(Vector2(position)) + Vector2(position).distance_to(head)


func _entry_position() -> Vector2:
	# A legacy save on an ambiguous trailing switch has no recoverable entry.
	# Preserve its outgoing half only; report insufficient history behind center.
	return Vector2(position) if incoming_heading == 0 else Vector2(position) - Vector2(RailNetworkScript.DELTAS[incoming_heading]) * 0.5


func _ensure_path() -> void:
	if _path_cell == position:
		return
	incoming_heading = heading
	if phase > 0:
		incoming_heading = _path.incoming_for(network, position, heading)
	_path.seed(network, position, incoming_heading)
	_path_cell = position


func reset() -> void:
	position = START_POSITION
	heading = START_HEADING
	distance_ticks = 0
	phase = 0
	blocked = false
	stop_reason = ""
	incoming_heading = START_HEADING
	_path_cell = Vector2i(-1, -1)
	_path.clear()


func snapshot() -> Dictionary:
	_ensure_path()
	return {
		"version": JOURNEY_VERSION,
		"incoming_heading": incoming_heading,
		"path": _path.snapshot(),
		"position": [position.x, position.y],
		"heading": heading,
		"distance_ticks": distance_ticks,
		"phase": phase,
		"blocked": blocked,
		"stop_reason": stop_reason,
	}


func restore(data: Variant) -> bool:
	if not data is Dictionary or not _has_snapshot_fields(data):
		return false
	if not _is_int_in_range(data.version, 1, JOURNEY_VERSION):
		return false
	var candidate_position: Variant = _parse_position(data.position)
	if candidate_position == null:
		return false
	if not _is_int_in_range(data.heading, 1, 9) or int(data.heading) == 5:
		return false
	if not _is_int_in_range(data.distance_ticks, 0, MAX_DISTANCE_REMAINDER):
		return false
	if not _is_int_in_range(data.phase, 0, PHASES_PER_TILE - 1):
		return false
	if typeof(data.blocked) != TYPE_BOOL:
		return false
	var reason := ""
	if int(data.version) >= 2:
		if not data.has("stop_reason") or typeof(data.stop_reason) != TYPE_STRING:
			return false
		reason = data.stop_reason
		if data.blocked == reason.is_empty():
			return false
	var restored_path = TrainPathScript.new()
	if int(data.version) >= 3:
		if not data.has("incoming_heading") or not _is_int_in_range(data.incoming_heading, 0, 9) or int(data.incoming_heading) == 5:
			return false
		if int(data.incoming_heading) == 0 and int(data.phase) == 0:
			return false
		var entry := Vector2(candidate_position) if int(data.incoming_heading) == 0 else Vector2(candidate_position) - Vector2(RailNetworkScript.DELTAS[int(data.incoming_heading)]) * 0.5
		if not data.has("path") or not restored_path.restore(data.path, entry):
			return false
	# Version 1 blocked only at the old x=33 trial boundary, which is ordinary track now.
	position = candidate_position
	heading = int(data.heading)
	distance_ticks = int(data.distance_ticks)
	phase = int(data.phase)
	blocked = data.blocked if int(data.version) >= 2 else false
	stop_reason = reason
	_path_cell = Vector2i(-1, -1)
	if int(data.version) >= 3:
		_path = restored_path
		incoming_heading = int(data.incoming_heading)
		_path_cell = position
	return true


func _has_snapshot_fields(data: Dictionary) -> bool:
	for field in ["version", "position", "heading", "distance_ticks", "phase", "blocked"]:
		if not data.has(field):
			return false
	return true


func _parse_position(value: Variant) -> Variant:
	if not value is Array or value.size() != 2:
		return null
	if not _is_int_in_range(value[0], 0, RailNetworkScript.WIDTH - 1) or not _is_int_in_range(value[1], 0, RailNetworkScript.HEIGHT - 1):
		return null
	var cell := Vector2i(int(value[0]), int(value[1]))
	if network != null and network.is_loaded() and network.tile(cell) == 0:
		return null
	return cell


func _is_int_in_range(value: Variant, minimum: int, maximum: int) -> bool:
	var value_type := typeof(value)
	var numeric := value_type == TYPE_INT or value_type == TYPE_FLOAT
	return numeric and is_finite(float(value)) and float(value) == floorf(float(value)) \
		and int(value) >= minimum and int(value) <= maximum
