extends RefCounted
# MIT. Presentation history; source TIME turns and travel regressions3Oct.
# Source: tasks/evidence/rail-network.md and tasks/evidence/station-arrival.md.
const RailNetworkScript = preload("res://scripts/rail_network.gd")


static func _advance_render(journey, fraction: float) -> void:
	if journey._render_path.points.is_empty():
		return
	# A center-seeded trailing switch has no known incoming half (see
	# _entry_position/_logical_fractional_position); retain only its outgoing half.
	var incoming_length := 0.0 if journey.incoming_heading == 0 else Vector2(RailNetworkScript.DELTAS[journey.incoming_heading]).length()
	var tile_length := (incoming_length + Vector2(RailNetworkScript.DELTAS[journey.heading]).length()) * 0.5
	journey._render_cursor += fraction * tile_length * (-1.0 if journey.reverse else 1.0)
	while journey._render_cursor > journey._render_path.length:
		var next: Vector2i = journey._render_end_cell + RailNetworkScript.DELTAS[journey._render_end_heading]
		if journey.network == null or not journey.network.entry_boundary(next).is_empty():
			journey._render_cursor = journey._render_path.length
			break
		var outgoing: int = journey.network.turn(next, journey._render_end_heading)
		journey._render_path.append_tile(next, journey._render_end_heading, outgoing)
		journey._render_end_cell = next
		journey._render_end_heading = outgoing
	while journey._render_cursor < 0.0:
		if not _extend_backing_path(journey):
			journey._render_cursor = 0.0
			break



static func _prepend_render(journey, points: PackedVector2Array) -> void:
	var added := 0.0
	var end: Vector2 = journey._render_path.points[0]
	for index in range(points.size()-1,-1,-1):
		added += points[index].distance_to(end)
		end = points[index]
	journey._render_path.points = points + journey._render_path.points
	journey._render_path.length += added
	journey._render_cursor += added
	journey._render_origin += added



static func _extend_backing_path(journey) -> bool:
	# Source rail ports/TIME turns. Seed history is finite; backing beyond it
	# must extend on live connected rails, rather than freeze at cursor zero.
	if journey._render_path.points.size() < 2:
		return false
	var start: Vector2 = journey._render_path.points[0]
	var delta: Vector2 = (journey._render_path.points[1]-start).sign()
	var cell := Vector2i((start-delta*0.5).round())
	var travel_heading := 0
	for candidate in RailNetworkScript.DELTAS:
		if Vector2(RailNetworkScript.DELTAS[candidate]) == -delta:
			travel_heading = candidate
	# Occupied-path trimming can leave the upcoming center as its first node.
	# Its incoming half is retained; only the unoccupied outgoing half is live.
	var starts_at_center: bool = start == start.round()
	if starts_at_center: cell = Vector2i(start)
	var station_interior: bool = cell == journey.next_cell() and journey.network.tile(cell) in [34,35,36,37]
	if travel_heading == 0 or (not journey.network.entry_boundary(cell).is_empty() and not station_interior):
		journey._render_refused_cell = cell
		journey._render_refused_heading = travel_heading
		return false
	if starts_at_center:
		var outgoing: int = journey.network.turn(cell,travel_heading)
		_prepend_render(journey,PackedVector2Array([start+Vector2(RailNetworkScript.DELTAS[outgoing])*0.5]))
		return true
	if station_interior:
		# Shared one-cell hidden station interior already used for departure
		# (station-arrival.md, owner26Sep). Backing puts the trailing locomotive
		# contact inside it before the head reaches the stopping port. This is
		# presentation history only; TIME still refuses the station cell.
		_prepend_render(journey, PackedVector2Array([Vector2(cell)+Vector2(RailNetworkScript.DELTAS[travel_heading])*0.5,Vector2(cell)]))
		return true
	var outgoing: int = journey.network.turn(cell,travel_heading)
	var port := Vector2(cell)+Vector2(RailNetworkScript.DELTAS[outgoing])*0.5
	if not Vector2(RailNetworkScript.DELTAS[outgoing])*0.5 in preload("res://scripts/rail_glyphs.gd").ports_for_code(journey.network.tile(cell)):
		return false
	_prepend_render(journey, PackedVector2Array([port,Vector2(cell)]))
	return true



static func _reroute_backing_turn(journey) -> void:
	# Only a measured command latch gives occupied history turn authority.
	# Legacy history retains source point turns (see earned7087 regression).
	var center := Vector2(journey.position)
	var index: int = journey._render_path.points.find(center)
	if index < 0:
		return
	if not journey.reverse_switches.is_empty() and index > 0:
		var outgoing: Vector2 = (journey._render_path.points[index-1]-center).sign()
		for candidate in RailNetworkScript.DELTAS:
			if Vector2(RailNetworkScript.DELTAS[candidate]) == outgoing:
				var key := "%d,%d" % [journey.position.x,journey.position.y]
				if candidate == journey.heading or journey.reverse_switches.get(key,0)==candidate:
					journey.heading = candidate
					return
	var removed := 0.0
	for step in range(index):
		removed += journey._render_path.points[step].distance_to(journey._render_path.points[step+1])
	journey._render_path.points = journey._render_path.points.slice(index)
	journey._render_path.length -= removed
	journey._render_cursor -= removed
	journey._render_origin -= removed
	_prepend_render(journey,PackedVector2Array([center+Vector2(RailNetworkScript.DELTAS[journey.heading])*0.5]))
	journey._render_cursor = maxf(0.0,journey._render_cursor)


static func _retain_reverse_occupied_path(journey, rear_distance: float) -> void:
	# Retain the node just ahead of the exact solved rear contact. All saved
	# nodes stay on source half-cell ports; no interpolated save geometry.
	var target: float = journey._render_cursor-rear_distance
	var arc := 0.0
	for index in range(1,journey._render_path.points.size()):
		var segment: float = journey._render_path.points[index-1].distance_to(journey._render_path.points[index])
		if arc+segment >= target:
			journey._render_path.points = journey._render_path.points.slice(index-1)
			journey._render_path.length -= arc
			journey._render_cursor -= arc
			journey._render_origin -= arc
			return
		arc += segment



static func _reroute_forward_turn(journey) -> void:
	# A reverser round trip retains render history. Its unoccupied future
	# must still follow the live TIME turn, rather than a cached switch choice.
	var index: int = journey._render_path.points.find(Vector2(journey.position))
	if index < 0:
		return
	journey._render_path.points = journey._render_path.points.slice(0,index+1)
	journey._render_path.length = 0.0
	for step in range(1,journey._render_path.points.size()):
		journey._render_path.length += journey._render_path.points[step-1].distance_to(journey._render_path.points[step])
	journey._render_path.append_tile(journey.position,journey.incoming_heading,journey.heading)
	journey._render_end_cell = journey.position
	journey._render_end_heading = journey.heading



static func _finish_render_boundary(journey) -> void:
	if journey._render_path.points.is_empty():
		return
	var target: Vector2 = journey._logical_fractional_position()
	# The terminal arrival owns the exact stopping port. The clock is paused
	# immediately afterwards, so no later draw may finish an unfinished approach.
	var cursor := 0.0
	for index in range(1,journey._render_path.points.size()):
		var start: Vector2 = journey._render_path.points[index-1]
		var end: Vector2 = journey._render_path.points[index]
		if Geometry2D.get_closest_point_to_segment(target,start,end).is_equal_approx(target):
			journey._render_cursor = cursor+start.distance_to(target)
			return
		cursor += start.distance_to(end)
	if journey.reverse and journey._render_path.points[0] == Vector2(journey.position):
		_prepend_render(journey, PackedVector2Array([target]))
		journey._render_cursor = 0.0



static func _render_sample(journey, distance: float) -> Dictionary:
	# Native normal-start save3Oct loses all six sprites on ordinary reverse
	# rails: the turn trims the prefix but only terminals previously refilled it.
	# Resolve every requested wagon contact from connected live rail geometry.
	if journey.reverse and journey.network != null:
		while distance > journey._render_cursor:
			if not _extend_backing_path(journey): break
	var trailing: float = journey._render_path.length - journey._render_cursor + distance
	return journey._render_path.sample(trailing, PackedVector2Array([journey._render_path.points[-1]]), journey.heading)
