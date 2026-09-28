extends Control

# source: tasks/evidence/panel-layout.md; yoda.alis form table 0x6bd0.
# This is a presentation layer: the owner handles the original command codes.
const LOGICAL_SIZE := Vector2(320, 200)
const STRIP := Rect2(0, 149, 320, 51)
# source: measured authored-asset alignment. Remove the surplus separator
# between wagon and map icons so each illustrated group meets the ECS hit boxes.
const ART_SLICES := [
	[Rect2(0, 184, 992, 402), Rect2(0, 149, 160, 51)],
	[Rect2(1058, 184, 480, 402), Rect2(160, 149, 70, 51)],
	[Rect2(1538, 184, 445, 402), Rect2(230, 149, 90, 51)],
]
const ART_PATH := "res://assets/interface/original-panel-v2.png"
const ICON_ATLAS_PATH := "res://assets/interface/panel-icons.png"
const COMMON := {
	2: Rect2(5, 164, 38, 29),
	6: Rect2(80, 161, 33, 15),
	8: Rect2(118, 162, 27, 14),
	7: Rect2(79, 180, 35, 14),
	9: Rect2(118, 179, 29, 17),
}
const MAP_COMMANDS := {
	4: Rect2(162, 160, 32, 19),
	1: Rect2(197, 160, 32, 19),
	3: Rect2(162, 180, 32, 19),
	5: Rect2(197, 180, 32, 19),
}
const WAGON_COMMANDS := {1: Rect2(161, 160, 33, 19)}
const LABELS := {1: "Map", 2: "Accelerate time", 3: "Reverse direction", 4: "Detailed map",
	5: "Brake", 6: "Engine", 7: "General Quarters", 8: "Boudoir", 9: "Missile launcher"}
# source: authored brass readouts for the new illustration, not historical pixels.
const READOUT_COLOR := Color("#ffe1a0")
const ICON_INK := Color("#342317") # source: authored dark ink on the brass/white plate.
# source: inner black-window bounds measured on original-panel.png and checked
# in tasks/validation/boudoir-quarters.png; excludes icon, rounded edge and rivets.
const READOUT_INNERS := [Rect2(1775, 299, 167, 54), Rect2(1775, 401, 167, 54), Rect2(1775, 505, 167, 54)]
const CLOCK_CENTER := Vector2(24, 180)

signal requested(code: int)

var reference_pixels := OS.get_environment("TRANSARTICA_REFERENCE_UI") == "1"
var ecs_art = preload("res://scripts/ecs_panel_art.gd").new()
var map_context := false
var overview_context := false
var app
var _texture: Texture2D
var _icon_atlas: Texture2D
var _last_state: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ecs_art.load_private()
	if ResourceLoader.exists(ART_PATH):
		_texture = load(ART_PATH) as Texture2D
	if ResourceLoader.exists(ICON_ATLAS_PATH):
		_icon_atlas = load(ICON_ATLAS_PATH) as Texture2D
	mouse_exited.connect(_clear_hover)
	resized.connect(queue_redraw)


func bind(value) -> void:
	app = value
	refresh()


func frame_rect() -> Rect2:
	var scale_factor := minf(size.x / LOGICAL_SIZE.x, size.y / LOGICAL_SIZE.y)
	var fitted := LOGICAL_SIZE * scale_factor
	return Rect2((size - fitted) / 2.0, fitted)


func screen_rect(logical: Rect2) -> Rect2:
	var frame := frame_rect()
	var scale_factor := frame.size.x / LOGICAL_SIZE.x
	return Rect2(frame.position + logical.position * scale_factor, logical.size * scale_factor)


func panel_rect() -> Rect2:
	return screen_rect(STRIP)


func logical_point(point: Vector2) -> Vector2:
	var frame := frame_rect()
	if frame.size.x <= 0.0:
		return Vector2(-1, -1)
	return (point - frame.position) * LOGICAL_SIZE.x / frame.size.x


func hotspot_at(point: Vector2) -> int:
	var logical := logical_point(point)
	for code in COMMON:
		if COMMON[code].has_point(logical):
			return code
	var contextual: Dictionary = MAP_COMMANDS if map_context else WAGON_COMMANDS
	for code in contextual:
		if contextual[code].has_point(logical):
			return code
	return 0


func _has_point(point: Vector2) -> bool:
	# The full-size control must not intercept clicks on the scene above the strip.
	return panel_rect().has_point(point)


func activate(code: int) -> void:
	var contextual: Dictionary = MAP_COMMANDS if map_context else WAGON_COMMANDS
	if COMMON.has(code) or contextual.has(code):
		requested.emit(code)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var code := hotspot_at(event.position)
		tooltip_text = LABELS.get(code, "")
		mouse_default_cursor_shape = CURSOR_POINTING_HAND if code != 0 else CURSOR_ARROW
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if ecs_art.available and ecs_art.scroll(self, logical_point(event.position)):
			accept_event()
			return
		var code := hotspot_at(event.position)
		if code != 0:
			activate(code)
			accept_event()


func _clear_hover() -> void:
	tooltip_text = ""
	mouse_default_cursor_shape = CURSOR_ARROW


func refresh() -> void:
	var state: Array = [map_context, overview_context]
	if app != null:
		state.append_array([app.engine.lignite, app.engine.anthracite, app.engine.speed,
			app.calendar.hour, app.calendar.minute, app.calendar.factor, app.engine.brake, app.journey.reverse, app.wagons.snapshot()])
	if state != _last_state:
		_last_state = state
		queue_redraw()


func _draw() -> void:
	if reference_pixels and ecs_art.available:
		ecs_art.draw(self)
		if app != null:
			_draw_readouts()
		return
	if _texture == null:
		return
	for slice in ART_SLICES:
		draw_texture_rect_region(_texture, screen_rect(slice[1]), slice[0])
	var frame := frame_rect()
	var scale_factor := frame.size.x / LOGICAL_SIZE.x
	draw_set_transform(frame.position, 0.0, Vector2.ONE * scale_factor)
	if not map_context:
		# Cover controls inactive in wagon context with the authored blank plate.
		for code in [1, 3, 5]:
			draw_texture_rect_region(_texture, MAP_COMMANDS[code], Rect2(758, 434, 207, 120))
	if app != null:
		if map_context and app.journey.reverse:
			draw_rect(MAP_COMMANDS[3].grow(-1), READOUT_COLOR, false, 1.0)
		_draw_clock()
	draw_set_transform(Vector2.ZERO)
	if app != null:
		_draw_readouts()
		_draw_composition()


func _draw_clock() -> void:
	# source: clock is a twelve-hour dial; calendar fields are decoded in game_calendar.gd.
	var minutes: float = app.calendar.minute
	var hours: float = app.calendar.hour % 12 + minutes / 60.0
	_clock_hand(minutes / 60.0, 9.0)
	_clock_hand(hours / 12.0, 6.0)


func _draw_readouts() -> void:
	_readout(str(app.engine.lignite), 0)
	_readout(str(app.engine.anthracite), 1)
	_readout(str(app.engine.speed), 2)


func readout_window(index: int) -> Rect2:
	if reference_pixels and ecs_art.available:
		# Original YODA coal icons at z32/20/8, adjacent numeric wells.
		return screen_rect(Rect2(278, 162 + 12 * index, 40, 11))
	var source: Rect2 = READOUT_INNERS[index]
	var source_slice: Rect2 = ART_SLICES[2][0]
	var logical_slice: Rect2 = ART_SLICES[2][1]
	var ratio := logical_slice.size / source_slice.size
	return screen_rect(Rect2(logical_slice.position + (source.position - source_slice.position) * ratio, source.size * ratio))


func readout_layout(value: String, index: int) -> Dictionary:
	# Account for the full font ascent/descent and the shadow, not only advance
	# width. One additional screen pixel guards the sampled inner window boundary.
	var window := readout_window(index).grow(-1.0)
	if window.size.x <= 1.0 or window.size.y <= 1.0:
		return {}
	var font := ThemeDB.fallback_font
	var font_size := maxi(1, roundi(7.0 * frame_rect().size.x / LOGICAL_SIZE.x))
	while font_size > 0:
		var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var ascent := font.get_ascent(font_size)
		var height := ascent + font.get_descent(font_size)
		var baseline := Vector2(floorf(window.end.x - width - 1.0), window.get_center().y - (height + 1.0) / 2.0 + ascent)
		var bounds := Rect2(baseline - Vector2(0, ascent), Vector2(width + 1.0, height + 1.0))
		if window.encloses(bounds):
			return {"font_size": font_size, "baseline": baseline, "bounds": bounds}
		font_size -= 1
	return {}


func _readout(value: String, index: int) -> void:
	var layout := readout_layout(value, index)
	if layout.is_empty():
		return
	var font := ThemeDB.fallback_font
	# source: authored one-screen-pixel shadow, included in readout_layout bounds.
	draw_string(font, layout.baseline + Vector2.ONE, value, HORIZONTAL_ALIGNMENT_LEFT, -1, layout.font_size, ICON_INK)
	draw_string(font, layout.baseline, value, HORIZONTAL_ALIGNMENT_LEFT, -1, layout.font_size, READOUT_COLOR)


func _draw_map_commands() -> void:
	if _icon_atlas == null:
		return
	# source: authored 1536x1024 atlas, six 512-square cells. Original ECS03/07
	# supplies the roles: overall map / return, reverser, STOP. The detailed-map
	# image remains baked into the plate. Preserve atlas aspect ratio in each slot.
	_draw_command_icon(4 if overview_context else 1, MAP_COMMANDS[1])
	_draw_command_icon(2, MAP_COMMANDS[3])
	_draw_command_icon(3, MAP_COMMANDS[5])


func _draw_command_icon(index: int, slot: Rect2) -> void:
	# source: one logical pixel inset leaves the illustrated brass frame visible;
	# square cell bounds retain the authored transparent padding and shadow.
	var available := slot.grow(-1.0)
	var side := minf(available.size.x, available.size.y)
	var destination := Rect2(available.get_center() - Vector2.ONE * side / 2.0, Vector2.ONE * side)
	var source := Rect2((index % 3) * 512, (index / 3) * 512, 512, 512)
	draw_texture_rect_region(_icon_atlas, destination, source)


func _clock_hand(turn: float, length: float) -> void:
	var direction := Vector2.UP.rotated(turn * TAU)
	draw_line(CLOCK_CENTER, CLOCK_CENTER + direction * length, ICON_INK, 1.0, true)


func _draw_composition() -> void:
	# Authored high-resolution miniatures reuse the train's own vehicle atlas.
	var renderer = app.world_view.train_renderer
	var right := 300
	var factor := frame_rect().size.x / LOGICAL_SIZE.x
	for index in range(ecs_art.first_wagon, app.wagons.count()):
		var wagon: Array = app.wagons.wagons[index]
		var kind: String = preload("res://scripts/train_consist.gd").TYPE_TO_KIND[int(wagon[0])]
		var vehicle: Dictionary = renderer.frame_for(kind)
		var width: int = ecs_art.wagon_width(wagon)
		if not vehicle.is_empty():
			var extent: Vector2 = vehicle.bounds.size
			var scale := minf((width - 2.0) / extent.y, 5.0 / extent.x) * factor
			var center := screen_rect(Rect2(right - width / 2.0, 153.5, 0, 0)).position
			draw_set_transform_matrix(renderer.registration(vehicle, center, -PI / 2, scale))
			draw_texture(vehicle.texture, Vector2.ZERO, Color("#7d6551") if int(wagon[1]) == 3 else Color.WHITE)
		right -= width
		if right < 14:
			break
	draw_set_transform_matrix(Transform2D.IDENTITY)
