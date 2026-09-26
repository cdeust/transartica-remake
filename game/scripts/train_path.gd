extends RefCounted

const Rails = preload("res://scripts/rail_network.gd")
const Glyphs = preload("res://scripts/rail_glyphs.gd")

# Source: rail_glyphs.gd ports and tasks/evidence/rail-network.md TIME deltas.
# Vertices describe the actual traversed center/port polyline, oldest first.
var points := PackedVector2Array()
var length := 0.0


func clear() -> void:
	points.clear()
	length = 0.0


func incoming_for(network, cell: Vector2i, outgoing: int) -> int:
	var choices := _incoming_choices(network, cell, outgoing)
	return choices[0] if choices.size() == 1 else 0


func _incoming_choices(network, cell: Vector2i, outgoing: int) -> Array[int]:
	var choices: Array[int] = []
	if network == null:
		return choices
	var ports: Array[Vector2] = Glyphs.ports_for_code(absi(network.tile(cell)))
	if not Vector2(Rails.DELTAS[outgoing]) * 0.5 in ports:
		return choices
	for candidate in Rails.DELTAS:
		if candidate == 5:
			continue
		if -Vector2(Rails.DELTAS[candidate]) * 0.5 in ports and network.turn(cell, candidate) == outgoing:
			choices.append(candidate)
	return choices


func seed(network, cell: Vector2i, incoming: int) -> void:
	clear()
	points.append(Vector2(cell) if incoming == 0 else Vector2(cell) - Vector2(Rails.DELTAS[incoming]) * 0.5)
	if incoming == 0:
		return
	var visited := {}
	var cursor := cell
	var direction := incoming
	# Stop at missing/ambiguous connectivity or a repeated directed state.
	while network != null:
		cursor -= Rails.DELTAS[direction]
		var key := Vector3i(cursor.x, cursor.y, direction)
		if visited.has(key):
			break
		visited[key] = true
		var choices := _incoming_choices(network, cursor, direction)
		if choices.size() != 1:
			break
		direction = choices[0]
		length += Vector2(Rails.DELTAS[direction]).length() * 0.5 + points[-1].distance_to(Vector2(cursor))
		points.append(Vector2(cursor))
		points.append(Vector2(cursor) - Vector2(Rails.DELTAS[direction]) * 0.5)
	points.reverse()


func append_tile(cell: Vector2i, incoming: int, outgoing: int) -> void:
	if points.is_empty():
		points.append(Vector2(cell) - Vector2(Rails.DELTAS[incoming]) * 0.5)
	length += points[-1].distance_to(Vector2(cell)) + Vector2(Rails.DELTAS[outgoing]).length() * 0.5
	if points[-1] != Vector2(cell):
		points.append(Vector2(cell))
	points.append(Vector2(cell) + Vector2(Rails.DELTAS[outgoing]) * 0.5)


func sample(distance: float, current: PackedVector2Array, heading: int) -> Dictionary:
	var remaining := distance
	var endpoint := current[current.size() - 1]
	for index in range(current.size() - 2, -1, -1):
		var result := _segment(current[index], endpoint, remaining, heading)
		if result.ok:
			return result
		remaining -= endpoint.distance_to(current[index])
		endpoint = current[index]
	for index in range(points.size() - 2, -1, -1):
		var result := _segment(points[index], endpoint, remaining, heading)
		if result.ok:
			return result
		remaining -= endpoint.distance_to(points[index])
		endpoint = points[index]
	return {"ok": false, "reason": "insufficient route history"}


func _segment(start: Vector2, end: Vector2, distance: float, fallback_heading: int) -> Dictionary:
	var segment_length := start.distance_to(end)
	if distance > segment_length:
		return {"ok": false}
	var tangent := (end - start).sign()
	var heading := fallback_heading
	for candidate in Rails.DELTAS:
		if candidate != 5 and Vector2(Rails.DELTAS[candidate]) == tangent:
			heading = candidate
	return {"ok": true, "position": end if segment_length == 0.0 else end.lerp(start, distance / segment_length), "heading": heading}


func snapshot() -> Array:
	var result := []
	for point in points:
		result.append([point.x, point.y])
	return result


func restore(data: Variant, expected_end: Vector2) -> bool:
	if not data is Array or data.is_empty():
		return false
	var candidate := PackedVector2Array()
	for value in data:
		if not value is Array or value.size() != 2:
			return false
		for number in value:
			if not typeof(number) in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(number)):
				return false
		var point := Vector2(value[0], value[1])
		if point.x < -0.5 or point.x > Rails.WIDTH - 0.5 or point.y < -0.5 or point.y > Rails.HEIGHT - 0.5:
			return false
		if not candidate.is_empty():
			var delta := (point - candidate[-1]).abs()
			if delta == Vector2.ZERO or delta.x > 0.5 or delta.y > 0.5 or (delta.x != 0.0 and delta.x != 0.5) or (delta.y != 0.0 and delta.y != 0.5):
				return false
		candidate.append(point)
	if candidate[-1] != expected_end:
		return false
	points = candidate
	length = 0.0
	for index in range(1, points.size()):
		length += points[index - 1].distance_to(points[index])
	return true
