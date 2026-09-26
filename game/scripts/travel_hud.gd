extends Control
class_name TravelHud

const BACKGROUND_PATH := "res://assets/engine-room/background.png"
const BACKGROUND_REGION := Rect2(0, 756, 1585, 236) # source: supplied 1585×992 engine-room plate.
const LOGICAL_SIZE := Vector2(1600, 244) # source: requested HUD coordinate system.
const MIN_HEIGHT := 210.0 # source: requested minimum HUD height.
const GOLD := Color("#ebbd70") # source: engine_room_controls.gd lower-panel overlay.
const PALE := Color("#e9e2cf") # source: engine_room_controls.gd instrument text.
const INK := Color("#11191c") # source: authored contrast shadow over supplied brass panel.
const HOVER := Color(1.0, 0.78, 0.38, 0.25) # source: authored transient pointer highlight.
const HOTSPOTS := {
	"pause": Rect2(30, 28, 205, 200),
	"room": Rect2(410, 28, 180, 82),
	"instruments": Rect2(610, 28, 180, 82),
	"follow": Rect2(803, 28, 338, 82),
	"journal": Rect2(410, 124, 180, 98),
	"brake": Rect2(610, 124, 180, 98),
	"regulator_down": Rect2(803, 124, 169, 98),
	"regulator_up": Rect2(972, 124, 169, 98),
	"lignite": Rect2(1270, 28, 305, 70),
	"anthracite": Rect2(1270, 110, 305, 65),
}

var session
var journey
var _background: Texture2D
var _font: Font
var _hover_id := ""
var _last_state: Array = []

signal requested(panel: String)
signal follow_requested


func _ready() -> void:
	custom_minimum_size.y = MIN_HEIGHT
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_font = ThemeDB.fallback_font
	_background = load(BACKGROUND_PATH) as Texture2D
	mouse_exited.connect(_on_mouse_exited)
	refresh()


func bind_session(value) -> void:
	session = value
	refresh()


func refresh() -> void:
	var state := _visible_state()
	if state == _last_state:
		return
	_last_state = state
	queue_redraw()


func _visible_state() -> Array:
	if session == null:
		return [_hover_id]
	var engine = session.engine
	return [engine.lignite, engine.anthracite, engine.lignite_rate, engine.anthracite_rate,
		engine.speed, engine.regulator, engine.brake, engine.cycles, session.paused,
		engine.event_pending, engine.event_message, _hover_id]


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var scale := size.x / LOGICAL_SIZE.x
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale)
	_draw_plate(LOGICAL_SIZE.y)
	if session != null:
		_draw_readouts()
	_draw_labels()
	_draw_hover()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_plate(logical_height: float) -> void:
	if _background == null:
		draw_rect(Rect2(Vector2.ZERO, Vector2(LOGICAL_SIZE.x, logical_height)), Color("#332b20"))
		return
	var plate_height := BACKGROUND_REGION.size.y * LOGICAL_SIZE.x / BACKGROUND_REGION.size.x
	var top := (logical_height - plate_height) * 0.5
	draw_texture_rect_region(_background, Rect2(0, top, LOGICAL_SIZE.x, plate_height), BACKGROUND_REGION)


func _draw_readouts() -> void:
	var engine = session.engine
	var minutes: int = engine.cycles * 3
	_text(Vector2(50, 24), "%02d:%02d" % [minutes / 60, minutes % 60], 17, GOLD)
	_text(Vector2(1405, 83), str(engine.lignite), 36, GOLD)
	_text(Vector2(1405, 153), str(engine.anthracite), 36, GOLD)
	_text(Vector2(1500, 215), str(engine.speed), 36, GOLD)
	_text(Vector2(641, 223), "BRAKE " + ("ON" if engine.brake else "OFF"), 15, GOLD)
	_text(Vector2(835, 155), "REGULATOR %03d" % engine.regulator, 15, PALE)
	_text(Vector2(864, 200), "−", 32, GOLD)
	_text(Vector2(1075, 200), "+", 32, GOLD)
	var message := "PAUSED · SPACE" if session.paused else "L %s · A %s" % [_rate_name(engine.lignite_rate), _rate_name(engine.anthracite_rate)]
	if session.engine.event_pending:
		message = session.engine.event_message
	elif journey != null and journey.at_station() and journey.station_result() >= 0:
		message = "IN STATION"
	elif journey != null and journey.blocked:
		message = "STOPPED · NOT PORTED"
	_text(Vector2(820, 67), message, 19, INK)


func _draw_labels() -> void:
	# Tooltips name the existing illustrated buttons without covering their artwork.
	if not _hover_id.is_empty():
		tooltip_text = _hover_id.replace("_", " ").to_upper()


func _draw_hover() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not _hover_id.is_empty() else Control.CURSOR_ARROW


func _text(point: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(_font, point + Vector2(1, 1), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)
	draw_string(_font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _rate_name(rate: int) -> String:
	return ["OFF", "NORMAL", "FAST"][clampi(rate, 0, 2)]


func _gui_input(event: InputEvent) -> void:
	if session == null:
		return
	if event is InputEventMouseMotion:
		_update_hover(_logical_point(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_activate_at(_logical_point(event.position))


func _logical_point(point: Vector2) -> Vector2:
	var scale := size.x / LOGICAL_SIZE.x
	if scale <= 0.0:
		return Vector2.ZERO
	return point / scale


func _update_hover(point: Vector2) -> void:
	var next_hover := ""
	for hotspot in HOTSPOTS:
		if HOTSPOTS[hotspot].has_point(point):
			next_hover = hotspot
			break
	if next_hover != _hover_id:
		_hover_id = next_hover
		refresh()


func _on_mouse_exited() -> void:
	if not _hover_id.is_empty():
		_hover_id = ""
		refresh()


func _activate_at(point: Vector2) -> void:
	for hotspot in HOTSPOTS:
		if HOTSPOTS[hotspot].has_point(point):
			_activate(String(hotspot))
			accept_event()
			return


func _activate(action: String) -> void:
	var engine = session.engine
	if engine.event_pending and action in ["brake", "regulator_down", "regulator_up", "lignite", "anthracite"]:
		return
	match action:
		"pause":
			session.paused = not session.paused
		"room": requested.emit("room")
		"instruments": requested.emit("instruments")
		"journal": requested.emit("journal")
		"follow": follow_requested.emit()
		"brake": engine.toggle_brake()
		"regulator_down": engine.set_regulator(engine.regulator - 15)
		"regulator_up": engine.set_regulator(engine.regulator + 15)
		"lignite": engine.cycle_lignite()
		"anthracite": engine.cycle_anthracite()
	refresh()
