extends RefCounted

# MIT. Presentation uses the authored sheet in visuals-20260927; topology stays
# with RailGlyphs and RailNetwork. Source crop and rail centres measured on its
# 1447x1087 canvas. Rendering repeats ballast/wood/steel along each live segment.
const TEXTURE_PATH := "res://assets/travel/rail-track-kit.png"
const STRIP := Rect2(85, 100, 195, 200)
const SOURCE_CENTER := 189.0 # source: rail-track-kit.png steel centres159/219 measured by source pixel scan.
const SOURCE_GAUGE := 60.0 # source: rail-track-kit.png source pixel scan159..219.
const TRACK_GAUGE := 20.0 # source: existing travel_world.gd _draw_rails_pair offsets ±10 pixels.
var texture: Texture2D


func load_art() -> bool:
	texture = load(TEXTURE_PATH) as Texture2D
	return texture != null


func draw_segment(canvas: CanvasItem, start: Vector2, finish: Vector2, zoom: float) -> bool:
	if texture == null:
		return false
	var distance := start.distance_to(finish)
	if distance <= 0.0:
		return true
	var scale_factor := TRACK_GAUGE * zoom / SOURCE_GAUGE
	var length := STRIP.size.y * scale_factor
	if length <= 0.0:
		return true
	canvas.draw_set_transform(start, (finish - start).angle() - PI / 2)
	var offset := 0.0
	while offset < distance:
		var drawn_length := minf(length, distance - offset)
		var source := Rect2(STRIP.position, Vector2(STRIP.size.x, drawn_length / scale_factor))
		var destination := Rect2((STRIP.position.x - SOURCE_CENTER) * scale_factor, offset, STRIP.size.x * scale_factor, drawn_length)
		canvas.draw_texture_rect_region(texture, destination, source)
		offset += drawn_length
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	return true


static func tile_segments(center: Vector2, endpoints: Array[Vector2]) -> Array:
	# Opposing ports form one authored straight, not two reversed crop halves.
	# Preserve RailGlyphs' centre/port chords for bends and junction branches.
	var result: Array = []
	var paired: Array[int] = []
	for first in endpoints.size():
		if first in paired:
			continue
		for second in range(first + 1, endpoints.size()):
			if second in paired:
				continue
			var a := (endpoints[first] - center).normalized()
			var b := (endpoints[second] - center).normalized()
			if a.is_equal_approx(-b):
				result.append([endpoints[first], endpoints[second]])
				paired.append_array([first, second])
				break
	for index in endpoints.size():
		if index not in paired:
			result.append([center, endpoints[index]])
	return result


static func joined_rails(start: Vector2, center: Vector2, finish: Vector2, half_gauge: float) -> Array:
	# Parallel offsets of the existing two centre chords meet at their line
	# intersection. The source ports/centre and the train path stay unchanged.
	var incoming := (center - start).normalized()
	var outgoing := (finish - center).normalized()
	var rails: Array = []
	for sign_value in [-1.0, 1.0]:
		var before: Vector2 = center + incoming.orthogonal() * half_gauge * sign_value
		var after: Vector2 = center + outgoing.orthogonal() * half_gauge * sign_value
		var intersection: Variant = Geometry2D.line_intersects_line(before, incoming, after, outgoing)
		if intersection != null:
			rails.append(PackedVector2Array([start + incoming.orthogonal() * half_gauge * sign_value,
				intersection, finish + outgoing.orthogonal() * half_gauge * sign_value]))
	return rails
