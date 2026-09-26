extends RefCounted

const Rails = preload("res://scripts/rail_network.gd")
const Consist = preload("res://scripts/train_consist.gd")
const MANIFEST := "res://assets/travel/vehicles.json"
const MIRRORS := {2: 6, 8: 4, 1: 9}
const REFERENCE_HEADING := 6
var _frames := {}
# Atlas texels per map cell, from the east locomotive anchors and its authored
# length. One constant for every vehicle and heading: artwork is never stretched.
var texels_per_cell := 0.0


func load_assets() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not parsed is Dictionary:
		return false
	for key in parsed.headings:
		var sheet: Dictionary = parsed.headings[key]
		var texture := load("res://assets/travel/" + sheet.file) as Texture2D
		if texture == null:
			return false
		var pixels := texture.get_image()
		if pixels.is_compressed():
			pixels.decompress()
		var frames := {}
		for kind in sheet.vehicles:
			var entry: Dictionary = sheet.vehicles[kind]
			var rect: Array = entry.region
			var region := Rect2(rect[0], rect[1], rect[2], rect[3])
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = region
			atlas.filter_clip = true
			frames[kind] = {"texture": atlas, "bounds": Rect2(pixels.get_region(Rect2i(region)).get_used_rect()), "front": Vector2(entry.front[0], entry.front[1]) - region.position, "rear": Vector2(entry.rear[0], entry.rear[1]) - region.position}
		_frames[int(key)] = frames
	var reference: Dictionary = _frames.get(REFERENCE_HEADING, {}).get("locomotive", {})
	if reference.is_empty():
		return false
	texels_per_cell = reference.front.distance_to(reference.rear) / Consist.LENGTHS.locomotive
	return true


func frame_for(kind: String, heading: int) -> Dictionary:
	var source_heading: int = MIRRORS.get(heading, heading)
	if not _frames.has(source_heading) or not _frames[source_heading].has(kind):
		return {}
	var frame: Dictionary = _frames[source_heading][kind].duplicate()
	frame.mirrored = MIRRORS.has(heading)
	frame.rotation = 0.0
	frame.reversed = false
	return frame


func poses(journey, consist, lag: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var distance := maxf(lag, 0.0)
	for kind in consist.vehicles:
		var length: float = Consist.LENGTHS[kind]
		var front: Dictionary = journey.sample_behind(distance)
		var rear: Dictionary = journey.sample_behind(distance + length)
		var middle: Dictionary = journey.sample_behind(distance + length * 0.5)
		if front.ok and rear.ok and middle.ok:
			var heading := _heading_for(front.position - rear.position, middle.heading)
			result.append({"kind": kind, "front": front.position, "rear": rear.position, "center": middle.position, "heading": heading})
		distance += length
	return result


func _heading_for(delta: Vector2, fallback: int) -> int:
	if delta.is_zero_approx():
		return fallback
	var best := fallback
	var score := -INF
	for heading in Rails.DELTAS:
		if heading == 5:
			continue
		var alignment := delta.normalized().dot(Vector2(Rails.DELTAS[heading]).normalized())
		if alignment > score:
			score = alignment
			best = heading
	return best


# Rigid placement: the midpoint of the measured front/rear rail-contact anchors
# sits on the midpoint of the sampled track chord, at the single texel scale.
# Only the heading frame follows the rails; the artwork keeps its proportions.
func registration(frame: Dictionary, front: Vector2, rear: Vector2, scale: float) -> Transform2D:
	var mirror := -1.0 if frame.mirrored else 1.0
	var anchor: Vector2 = (frame.front + frame.rear) * 0.5
	var basis_x := Vector2(scale * mirror, 0.0)
	var basis_y := Vector2(0.0, scale)
	return Transform2D(basis_x, basis_y, (front + rear) * 0.5 - basis_x * anchor.x - basis_y * anchor.y)


# Screen pixels per atlas texel at the view's current zoom.
func texel_scale(view) -> float:
	var cell: Vector2 = view._world_to_screen(Vector2(1.0, 0.0)) - view._world_to_screen(Vector2.ZERO)
	return cell.length() / texels_per_cell


func draw(view, journey, consist, lag: float) -> void:
	var vehicles := poses(journey, consist, lag)
	var scale := texel_scale(view)
	vehicles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return view._project(a.center).y < view._project(b.center).y)
	for vehicle in vehicles:
		var frame := frame_for(vehicle.kind, vehicle.heading)
		if frame.is_empty():
			continue
		var front: Vector2 = view._world_to_screen(vehicle.front + Vector2(0.5, 0.5))
		var rear: Vector2 = view._world_to_screen(vehicle.rear + Vector2(0.5, 0.5))
		view.draw_set_transform_matrix(registration(frame, front, rear, scale))
		view.draw_texture(frame.texture, Vector2.ZERO)
	view.draw_set_transform_matrix(Transform2D.IDENTITY)


func screen_bounds(view, journey, consist, lag: float) -> Rect2:
	var result := Rect2()
	var initialized := false
	var scale := texel_scale(view)
	for vehicle in poses(journey, consist, lag):
		var frame := frame_for(vehicle.kind, vehicle.heading)
		if frame.is_empty():
			continue
		var front: Vector2 = view._world_to_screen(vehicle.front + Vector2(0.5, 0.5))
		var rear: Vector2 = view._world_to_screen(vehicle.rear + Vector2(0.5, 0.5))
		var transform := registration(frame, front, rear, scale)
		var rect: Rect2 = frame.bounds
		for point in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var screen: Vector2 = transform * point
			result = result.expand(screen) if initialized else Rect2(screen, Vector2.ZERO)
			initialized = true
	return result
