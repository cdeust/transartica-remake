extends Control
class_name EngineInstruments

const InstrumentArt = preload("res://scripts/instrument_art.gd")

const LOGICAL_SIZE := Vector2(1600.0, 1000.0) # source: authored full-screen interaction grid.
const REGULATOR_AREA := Rect2(475, 42, 650, 225) # source: Transarctica Amiga manual, ENGINE CONTROLS diagram E.
const REGULATOR_MIN_X := 500.0 # source: authored hit projection for manual control E.
const REGULATOR_MAX_X := 1100.0 # source: authored hit projection for manual control E.
const BACK_AREA := Rect2(1190, 690, 345, 255) # source: Transarctica Amiga manual, ENGINE CONTROLS item F.
const REGULATOR_MAX := 300.0 # source: tasks/evidence/locomotive-rules.md, TRAIN regulator range.
const HEAT_EVENT := 5000 # source: tasks/evidence/locomotive-rules.md, overload comparison.

var session
var _last_state: Array = []

signal requested(action: String)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func bind_session(value) -> void:
	session = value
	_last_state = []
	queue_redraw()


func refresh() -> void:
	if session == null:
		return
	var state := _state_values()
	if state != _last_state:
		_last_state = state
		queue_redraw()


func instrument_values() -> Dictionary:
	if session == null:
		return {}
	var engine = session.engine
	return {
		"boiler_pressure_raw": engine.heat,
		"speed_kmh": engine.speed,
		"piston_pressure": engine.pressure_reserve / 200,
		"piston_pressure_modelled": true,
		"temperature_raw": engine.temperature,
		"regulator": engine.regulator,
		"heat_raw": engine.heat,
		"heat_event_if_above": HEAT_EVENT,
		"lignite_rate": engine.lignite_rate,
		"anthracite_rate": engine.anthracite_rate,
		"event_pending": engine.event_pending,
	}


func _state_values() -> Array:
	var engine = session.engine
	return [engine.pressure_reserve, engine.speed, engine.temperature, engine.regulator,
		engine.heat, engine.lignite_rate, engine.anthracite_rate, engine.event_pending,
		engine.event_message, session.paused, engine.cycles]


func logical_to_screen(point: Vector2) -> Vector2:
	var rect := _canvas_rect()
	return rect.position + point * (rect.size / LOGICAL_SIZE)


func _canvas_rect() -> Rect2:
	var scale := minf(size.x / LOGICAL_SIZE.x, size.y / LOGICAL_SIZE.y)
	var fitted := LOGICAL_SIZE * maxf(scale, 0.0)
	return Rect2((size - fitted) * 0.5, fitted)


func _draw() -> void:
	if session == null:
		return
	var rect := _canvas_rect()
	draw_set_transform(rect.position, 0.0, rect.size / LOGICAL_SIZE)
	InstrumentArt.render(self, session.engine)


func _gui_input(event: InputEvent) -> void:
	if session == null or not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	_handle_click(_screen_to_logical(event.position))
	accept_event()


func _screen_to_logical(point: Vector2) -> Vector2:
	var rect := _canvas_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Vector2.ZERO
	return (point - rect.position) * (LOGICAL_SIZE / rect.size)


func _handle_click(point: Vector2) -> void:
	if BACK_AREA.has_point(point):
		requested.emit("room")
	elif REGULATOR_AREA.has_point(point) and not session.engine.event_pending:
		var ratio := inverse_lerp(REGULATOR_MIN_X, REGULATOR_MAX_X, point.x)
		session.engine.set_regulator(clampf(ratio, 0.0, 1.0) * REGULATOR_MAX)
	refresh()
