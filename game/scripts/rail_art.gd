extends RefCounted

# MIT. Presentation uses the authored sheet in visuals-20260927; topology stays
# with RailGlyphs and RailNetwork. Source crop and rail centres measured on its
# 1447x1087 canvas. Rendering repeats ballast/wood/steel along each live segment.
const TEXTURE_PATH := "res://assets/travel/rail-track-kit.png"
const STRIP := Rect2(85, 100, 195, 200)
const SOURCE_GAUGE := 70.0 # measured rail centre separation within STRIP.
const TRACK_GAUGE := 20.0 # existing travel_world.gd paired rails, ±10 pixels.
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
		var destination := Rect2(-STRIP.size.x * scale_factor / 2, offset, STRIP.size.x * scale_factor, drawn_length)
		canvas.draw_texture_rect_region(texture, destination, source)
		offset += drawn_length
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	return true
