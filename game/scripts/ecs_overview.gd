extends Control

# MIT. Exact private plan layout: CARTE resource192, palette196.
# source: tasks/evidence/map-orientation-audit.md. Historical pixels are never bundled.
const CANVAS := Vector2(320, 149)
const PLAN_PATH := "res://../reference-private/general-plan.json"
const RailNetwork = preload("res://scripts/rail_network.gd")
const MARKER := Color("#c62823") # source: ECS04 stopped position cross.
signal inspected(cell: Vector2i)
var lens_point := Vector2.ZERO
var lens_visible := false
var journey
var engine
var chart = preload("res://scripts/overview_chart_art.gd").new()
var reference_pixels := OS.get_environment("TRANSARTICA_REFERENCE_UI") == "1"
var authored_available := false
var plan_texture: ImageTexture
var unavailable_reason := "GENERAL MAP DATA UNAVAILABLE"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
	mouse_exited.connect(func(): lens_visible = false; queue_redraw())
	if reference_pixels:
		load_plan(PLAN_PATH)
	else:
		chart.load_art()


func load_plan(path: String) -> bool:
	plan_texture = null
	if not FileAccess.file_exists(path):
		queue_redraw()
		return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return false
	var pixels := decode_plan(parser.data)
	if pixels.is_empty():
		return false
	plan_texture = ImageTexture.create_from_image(Image.create_from_data(int(CANVAS.x), int(CANVAS.y), false, Image.FORMAT_RGB8, pixels))
	queue_redraw()
	return true


static func decode_plan(data: Variant) -> PackedByteArray:
	var empty := PackedByteArray()
	if not data is Dictionary or data.get("version") != 1 or data.get("width") != 320 or data.get("height") != 149:
		return empty
	var palette = data.get("palette")
	var rows = data.get("rows")
	if not palette is Array or palette.size() != 16 or not rows is Array or rows.size() != 149:
		return empty
	for color in palette:
		if not color is Array or color.size() != 3:
			return empty
		for channel in color:
			if not _integer_in_range(channel, 0, 255):
				return empty
	var pixels := PackedByteArray()
	for row in rows:
		if not row is Array or row.is_empty() or row.size() > 320:
			return empty
		var width := 0
		for run in row:
			if not run is Array or run.size() != 2 or not _integer_in_range(run[0], 0, 15) or not _integer_in_range(run[1], 1, 320):
				return empty
			width += int(run[1])
			if width > 320:
				return empty
			for pixel in int(run[1]):
				pixels.append_array(PackedByteArray(palette[int(run[0])]))
		if width != 320:
			return empty
	return pixels


static func _integer_in_range(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum


func map_point(cell: Vector2) -> Vector2:
	# source: CARTE0x1ece x=2*worldX+2,z=196-2*worldY; screen y=199-z.
	return Vector2(2 * cell.x + 2, 2 * cell.y + 3)


func _draw() -> void:
	if not reference_pixels:
		authored_available = chart.available()
	if (reference_pixels and plan_texture == null) or (not reference_pixels and not authored_available):
		draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
		draw_string(ThemeDB.fallback_font, size * 0.5, unavailable_reason)
		return
	if reference_pixels:
		draw_texture_rect(plan_texture, Rect2(Vector2.ZERO, size), false)
	else:
		draw_set_transform(Vector2.ZERO,0,size/CANVAS)
		chart.draw(self)
		draw_set_transform(Vector2.ZERO)
	if journey == null:
		return
	draw_set_transform(Vector2.ZERO, 0, size / CANVAS)
	var point := map_point(Vector2(journey.position))
	# source: original manual overall-map controls: stopped cross / moving arrow.
	if engine == null or engine.speed == 0 or journey.blocked:
		draw_line(point - Vector2(3, 3), point + Vector2(3, 3), MARKER, 1)
		draw_line(point + Vector2(-3, 3), point + Vector2(3, -3), MARKER, 1)
	else:
		var direction := Vector2(RailNetwork.DELTAS.get(journey.heading, Vector2i.RIGHT)).normalized()
		var side := direction.orthogonal()
		draw_line(point - direction * 3, point + direction * 3, MARKER, 1)
		draw_polyline(PackedVector2Array([point + side * 2, point + direction * 3, point - side * 2]), MARKER, 1)
	_draw_lens()
	draw_set_transform(Vector2.ZERO)


func _gui_input(event: InputEvent) -> void:
	if (reference_pixels and plan_texture == null) or (not reference_pixels and not authored_available):
		return
	if event is InputEventMouse:
		# source: CARTE0x1f21..0x1f87 x19..300,z59..187; screen y=199-z.
		lens_point = (event.position * CANVAS / size).clamp(Vector2(19, 12), Vector2(300, 140))
		lens_visible = true
		queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# source: CARTE0x235b..0x244a coordinates; normal caller emits message3.
		inspected.emit(Vector2i(int(lens_point.x / 2), int((lens_point.y - 6) / 2)))
		accept_event()


func _draw_lens() -> void:
	if not lens_visible:
		return
	# source: measured resource194 aperture/frame geometry in map-orientation-audit.md.
	# New vector brass housing, preserving the original placement and function.
	var frame := Rect2(lens_point + Vector2(-24, -13), Vector2(46, 26))
	var brass := Color("#91936b")
	var edge := Color("#444b38")
	draw_line(lens_point + Vector2(15, 9), lens_point + Vector2(34, 30), edge, 9)
	draw_line(lens_point + Vector2(15, 9), lens_point + Vector2(34, 30), brass, 5)
	draw_rect(frame, edge, false, 2)
	draw_rect(frame.grow(-2), brass, false, 2)
	draw_rect(frame.grow(-4), Color("#f2f2d4"), false, 1)
	var factor := size.x / CANVAS.x
	draw_set_transform(Vector2.ZERO)
	var font_size := maxi(1, roundi(5 * factor))
	var x_label := str(int(lens_point.x / 2))
	var y_label := str(int((lens_point.y - 6) / 2))
	for label in [[x_label, Vector2(-3, 22)], [y_label, Vector2(25, 0)]]:
		draw_string(ThemeDB.fallback_font, (lens_point + label[1]) * size / CANVAS, label[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, edge)
