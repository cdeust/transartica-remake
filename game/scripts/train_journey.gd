extends RefCounted
class_name TrainJourney

const RailNetworkScript = preload("res://scripts/rail_network.gd")
const Render = preload("res://scripts/train_journey_render.gd")
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
const JOURNEY_VERSION := 6 # source: persisted physical boundary, approved adaptation3Oct.
const HEADING_NAMES := {1: "SOUTH-WEST", 2: "SOUTH", 3: "SOUTH-EAST", 4: "WEST", 6: "EAST", 7: "NORTH-WEST", 8: "NORTH", 9: "NORTH-EAST"}

var network # RailNetwork, assigned by the owner of the world data.
var position := START_POSITION
var heading := START_HEADING
var distance_ticks := 0
var phase := 0
var blocked := false
var stop_reason := ""
# Owner-approved physical rear-contact boundary,3Oct; original works costs unchanged.
# Field name retains obstacle origin; stations also use boundary_cell().
var physical_obstacle := Vector2i(-1,-1)
var _render_refused_cell := Vector2i(-1,-1)
var physical_heading := 0
# source: YODA0x2713 refusal retains posted spy; resume this entry after its answer.
var physical_spy_handled := false
var _render_refused_heading := 0
var _path = TrainPathScript.new()
var incoming_heading := START_HEADING
var _path_cell := Vector2i(-1, -1)
var reverse := false
var _render_path = TrainPathScript.new()
var _render_cursor := 0.0
var _render_origin := 0.0 # Offset keeps arc coordinates stable when history is prepended.
var _render_end_cell := Vector2i.ZERO
var _render_end_heading := START_HEADING
var reverse_switches: Dictionary = {} # source: occupied-switch continuity, owner4Oct.


func advance(speed: int) -> void:
	if blocked or speed <= 0 or network == null or not network.is_loaded():
		return
	_ensure_path()
	var progress: int = mini(network.progress_speed(position, heading, speed), MAX_PROGRESS_SPEED)
	Render._advance_render(self, float(progress / 20) / float(PHASES_PER_TILE * DISTANCE_STEP))
	distance_ticks += progress / 20
	if distance_ticks <= MAX_DISTANCE_REMAINDER:
		return
	distance_ticks -= DISTANCE_STEP
	phase += 1
	if phase < PHASES_PER_TILE:
		if phase == TURN_PHASE:
			heading = network.turn(position, heading)
			if not _render_path.points.is_empty():
				Render._reroute_backing_turn(self) if reverse else Render._reroute_forward_turn(self)
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
	Render._finish_render_boundary(self)


# YODA0x18e3..1970. The caller stops the engine; reverse is main+0x2fbc.
# Preserve canonical rail geometry: reversing traction never turns the wagons.
func reverse_direction() -> bool:
	_ensure_path()
	if _render_path.points.is_empty():
		var initial_cursor := distance_travelled()
		_render_path.points = _path.points.duplicate()
		_render_path.length = _path.length
		_render_cursor = initial_cursor
		_render_end_cell = position
		_render_end_heading = network.turn(position, heading) if phase == 0 and network != null else heading
		_render_path.append_tile(position, incoming_heading, _render_end_heading)
	reverse = not reverse
	if not reverse: reverse_switches.clear()
	heading = 10 - heading
	incoming_heading = heading
	phase = absi(phase - 2) - 1
	distance_ticks = DISTANCE_STEP
	blocked = false
	stop_reason = ""
	physical_obstacle = Vector2i(-1,-1)
	physical_heading = 0
	physical_spy_handled = false
	# Logical route must follow its new heading, but rendering keeps its old route.
	_path_cell = Vector2i(-1, -1)
	return true


func at_obstacle() -> bool:
	return blocked and stop_reason == RailNetworkScript.OBSTACLE_REASON


# After YODA 0x2390 repairs the cell, TIME's next phase-3 step retries the entry.
func resume_after_works() -> bool:
	if not at_obstacle():
		return false
	blocked = false
	stop_reason = ""
	if physical_obstacle != Vector2i(-1,-1) and network.entry_boundary(physical_obstacle).is_empty():
		physical_obstacle = Vector2i(-1,-1)
		physical_heading = 0
		physical_spy_handled = false
	return true


# Event cells whose YODA handler ends with the 0x18e3 reversal (obstacles.md):
# the closed bridge -120 (text 52). The workshop 65 and mines 78 follow once ported.
func at_reversal_event() -> bool:
	return blocked and stop_reason == "event site" and network != null \
			and network.tile(boundary_cell()) in RailNetworkScript.REVERSAL_EVENTS


func at_station() -> bool:
	return blocked and stop_reason == "station"


# TIME 0x26fb result for the refused station ahead; see RailNetwork.station_lookup.
func station_result() -> int:
	return network.station_lookup(boundary_cell()) if at_station() and network != null else -1


# yoda 0x18e3, reached from glieu message 9 (tasks/evidence/station-arrival.md).
# Heading 1<->9, 2<->8, 3<->7, 4<->6. The original sets phase |2 - 2| - 1 = -1
# with remainder 23; progress per step is mini(speed, 450) / 20 <= 22, so its
# next moving step lands on phase 0 with remainder progress/20, exactly like
# phase 0 / remainder 0 here. Engine speed is reset by the caller.
func depart_from_station() -> bool:
	if not at_station() and not at_reversal_event():
		return false
	var station := boundary_cell()
	var toward_station: int = physical_heading if physical_heading != 0 else heading
	# The station hides its interior (owner26Sep); emergence starts at its exit,
	# including a reverse-tail arrival whose locomotive logical point is remote.
	position = station - RailNetworkScript.DELTAS[toward_station]
	heading = toward_station
	# Station emergence starts fresh (station-arrival.md, owner26Sep).
	reverse_switches.clear()
	_render_path.clear()
	_render_cursor = 0.0
	_render_origin = 0.0
	reverse = false
	heading = 10 - heading
	incoming_heading = heading
	distance_ticks = 0
	phase = 0
	blocked = false
	stop_reason = ""
	physical_obstacle = Vector2i(-1,-1)
	physical_heading = 0
	physical_spy_handled = false
	# Presentation (owner choice, 26 September 2026): the convoy leaves the
	# station behind the locomotive. The station tile has no decoded rail
	# interior geometry, so one straight hidden cell stands in for it; wagons further
	# back have no history yet and emerge as the train moves away.
	var step := Vector2(RailNetworkScript.DELTAS[toward_station]) * 0.5
	_path.clear()
	_path.points = PackedVector2Array([Vector2(station) + step, Vector2(station), Vector2(station) - step])
	_path.length = step.length() * 2.0
	_path_cell = position
	return true


# True when the route history begins in a station (depart_from_station): the
# missing wagons are inside it, not lost. seed() never enters a station tile,
# whose single terminal port cannot seed a traversable interior.
func history_starts_in_station() -> bool:
	if _path.points.size() < 2 or network == null:
		return false
	var center: Vector2 = _path.points[1]
	if center != center.floor():
		return false
	var code: int = network.tile(Vector2i(center))
	return (code >= 34 and code <= 37) or code in RailNetworkScript.REVERSAL_EVENTS


func heading_name() -> String:
	return HEADING_NAMES.get(heading, "STOPPED")


func boundary_cell() -> Vector2i:
	return physical_obstacle if physical_obstacle != Vector2i(-1,-1) else next_cell()


func obstacle_cell() -> Vector2i:
	return physical_obstacle if physical_obstacle != Vector2i(-1,-1) else next_cell()


func next_cell() -> Vector2i:
	return position + RailNetworkScript.DELTAS.get(heading, Vector2i.ZERO)


# Presentation adaptation: rail_glyphs.gd draws half-tile ports joined at centers.
# TIME phases remain unchanged: phase 1 selects the outgoing rail, before the
# head reaches the center. The head crosses each cell at a constant rate over
# its three phases instead of the entry half in one phase and the exit in two.
func fractional_position() -> Vector2:
	_ensure_path()
	if not _render_path.points.is_empty():
		var sample: Dictionary = Render._render_sample(self, 0.0)
		if sample.ok:
			return sample.position
	return _logical_fractional_position()


func _logical_fractional_position() -> Vector2:
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
	if not _render_path.points.is_empty():
		return Render._render_sample(self, distance_world)
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
	if not _render_path.points.is_empty():
		return _render_cursor-_render_origin
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
	reverse_switches.clear()
	reverse = false
	_render_path.clear()
	_render_cursor = 0.0
	_render_origin = 0.0
	position = START_POSITION
	heading = START_HEADING
	distance_ticks = 0
	phase = 0
	blocked = false
	stop_reason = ""
	physical_obstacle = Vector2i(-1,-1)
	physical_heading = 0
	physical_spy_handled = false
	incoming_heading = START_HEADING
	_path_cell = Vector2i(-1, -1)
	_path.clear()


func snapshot() -> Dictionary:
	_ensure_path()
	return {
		"version": JOURNEY_VERSION,
		"physical_obstacle": [physical_obstacle.x,physical_obstacle.y],
		"physical_heading": physical_heading,
		"physical_spy_handled": physical_spy_handled,
		"reverse": reverse,
		"reverse_switches": reverse_switches.duplicate(),
		"render_path": _render_path.snapshot(),
		"render_cursor": _render_cursor,
		"render_origin": _render_origin,
		"render_end_cell": [_render_end_cell.x, _render_end_cell.y],
		"render_end_heading": _render_end_heading,
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
	if not _valid_snapshot(data): return false
	var candidate_position: Variant = _parse_position(data.position)
	var obstacle := Vector2i(-1,-1)
	var spy_handled: Variant = data.get("physical_spy_handled",false)
	if not spy_handled is bool: return false
	if int(data.version) >= 6:
		var raw: Variant = data.get("physical_obstacle")
		if not raw is Array or raw.size() != 2: return false
		if not _is_int_in_range(data.get("physical_heading"),0,9) or int(data.physical_heading)==5: return false
		if not (_is_int_in_range(raw[0],-1,-1) and _is_int_in_range(raw[1],-1,-1)):
			var parsed: Variant = _parse_position(raw)
			if parsed == null or data.get("reverse",false) != true: return false
			# source: RailNetwork.entry_boundary; physical pre-entry can suspend
			# before a hidden record is revealed or before its event is handled.
			if data.blocked and data.get("stop_reason","") not in [RailNetworkScript.OBSTACLE_REASON,"station","special site","event site"]: return false
			if not _is_int_in_range(data.get("physical_heading"),1,9) or int(data.physical_heading)==5: return false
			obstacle = parsed
	if spy_handled and obstacle == Vector2i(-1,-1): return false
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
	var renderer := _restore_renderer(data)
	if renderer.is_empty(): return false
	var switches: Variant = data.get("reverse_switches",{})
	if not switches is Dictionary: return false
	for key in switches:
		if not key is String: return false
		var parts: PackedStringArray = key.split(",")
		if parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return false
		var cell := Vector2i(int(parts[0]),int(parts[1]))
		if key != "%d,%d" % [cell.x,cell.y] or network==null or not network.is_switch(cell): return false
		if not _is_int_in_range(switches[key],1,9) or int(switches[key])==5: return false
		var index: int = renderer.path.points.find(Vector2(cell))
		if index<1 or renderer.path.points[index-1] != Vector2(cell)+Vector2(RailNetworkScript.DELTAS[int(switches[key])])*0.5: return false
		if not data.get("reverse",false): return false
	# Version 1 blocked only at the old x=33 trial boundary, which is ordinary track now.
	_render_path = renderer.path
	reverse_switches = switches.duplicate()
	reverse = data.get("reverse", false)
	_render_cursor = renderer.cursor
	_render_origin = float(data.get("render_origin", 0.0))
	_render_end_cell = renderer.end
	_render_end_heading = int(data.get("render_end_heading", START_HEADING))
	position = candidate_position
	heading = int(data.heading)
	distance_ticks = int(data.distance_ticks)
	phase = int(data.phase)
	blocked = data.blocked if int(data.version) >= 2 else false
	stop_reason = reason
	physical_obstacle = obstacle
	physical_heading = int(data.get("physical_heading",0))
	physical_spy_handled = spy_handled
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


func _restore_renderer(data: Dictionary) -> Dictionary:
	var render_candidate = TrainPathScript.new()
	var render_end := Vector2i.ZERO
	var cursor := 0.0
	if int(data.version) >= 4:
		if not data.get("reverse") is bool or not data.get("render_path") is Array:
			return {}
		if not _is_int_in_range(data.get("render_end_heading"), 1, 9) or int(data.render_end_heading) == 5:
			return {}
		var parsed_end: Variant = _parse_position(data.get("render_end_cell"))
		if parsed_end == null and not data.render_path.is_empty():
			return {}
		render_end = parsed_end if parsed_end != null else Vector2i.ZERO
		if not data.get("render_cursor") is float and not data.get("render_cursor") is int:
			return {}
		if not is_finite(float(data.render_cursor)) or float(data.render_cursor) < 0.0:
			return {}
		cursor = float(data.render_cursor)
		if (int(data.version) >= 5 or data.has("render_origin")) and (not typeof(data.get("render_origin")) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data.render_origin))):
			return {}
		if not data.render_path.is_empty():
			var end := Vector2(render_end) + Vector2(RailNetworkScript.DELTAS[int(data.render_end_heading)]) * 0.5
			if not render_candidate.restore(data.render_path, end):
				return {}
			# Earned Turin11591: accumulated arc exceeds its recomputed sum by
			# 4e-14 cells. Godot4.5 @GlobalScope.is_equal_approx handles rounding.
			if cursor > render_candidate.length and not is_equal_approx(cursor,render_candidate.length):
				return {}
			cursor = minf(cursor,render_candidate.length)
	return {"path":render_candidate,"end":render_end,"cursor":cursor}


func _valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary or not _has_snapshot_fields(data):
		return false
	if not _is_int_in_range(data.version, 1, JOURNEY_VERSION):
		return false
	if _parse_position(data.position) == null:
		return false
	if not _is_int_in_range(data.heading, 1, 9) or int(data.heading) == 5:
		return false
	if not _is_int_in_range(data.distance_ticks, 0, DISTANCE_STEP if int(data.version) >= 4 else MAX_DISTANCE_REMAINDER):
		return false
	if not _is_int_in_range(data.phase, -1 if int(data.version) >= 4 else 0, PHASES_PER_TILE - 1):
		return false
	if typeof(data.blocked) != TYPE_BOOL:
		return false
	return true
