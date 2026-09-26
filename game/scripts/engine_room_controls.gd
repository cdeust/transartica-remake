extends Control

# source: tasks/evidence/engine-room-integration.md; authored hit regions and typography.
const GOLD := Color("#ebbd70")
const PALE := Color("#e9e2cf")
const HOTSPOTS := [
	["gauges", Rect2(825, 116, 180, 66), "INSTRUMENTS · click to inspect"],
	["lignite", Rect2(405, 400, 310, 326), "LIGNITE · click: OFF / NORMAL / FAST · key L"],
	["anthracite", Rect2(996, 408, 234, 318), "ANTHRACITE · click: OFF / NORMAL / FAST · key A"],
	["lignite", Rect2(1270, 783, 305, 71), "LIGNITE · fuel and currency · key L"],
	["anthracite", Rect2(1270, 860, 305, 61), "ANTHRACITE · richer fuel · key A"],
	["regulator", Rect2(550, 72, 140, 215), "REGULATOR · drag the engineer · arrow keys"],
	["pause", Rect2(32, 790, 199, 205), "CLOCK · pause / resume · Space"],
	["map", Rect2(803, 785, 338, 86), "ROUTE CHART · M"],
	["journal", Rect2(416, 885, 178, 105), "JOURNAL · J"],
	["brake", Rect2(610, 885, 182, 105), "BRAKE · apply / release · B"],
]

var session
var art
var hover_id := ""
var hover_hint := ""
var hover_rect := Rect2()
var dragging_regulator := false
var show_help := false
var show_instruments := false
var notice := ""
var notice_seconds := 0.0
var _font: Font
var _last_refresh_state: Array = []
signal requested(action: String)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	mouse_exited.connect(_clear_hover)


func refresh(delta: float) -> void:
	var was_notice_visible := notice_seconds > 0.0
	if was_notice_visible:
		notice_seconds = maxf(0.0, notice_seconds - delta)
	var state := _visible_state()
	if was_notice_visible and notice_seconds <= 0.0 or state != _last_refresh_state:
		_last_refresh_state = state
		queue_redraw()


func _visible_state() -> Array:
	if session == null:
		return [hover_id, hover_hint, show_help, show_instruments, notice, notice_seconds > 0.0]
	var engine = session.engine
	return [engine.lignite, engine.anthracite, engine.lignite_rate, engine.anthracite_rate,
		engine.regulator, engine.speed, engine.temperature, engine.heat, engine.pressure_reserve,
		engine.brake, engine.event_pending, engine.event_message, engine.cycles, session.paused,
		hover_id, hover_hint, show_help, show_instruments, notice, notice_seconds > 0.0]


func announce(message: String) -> void:
	notice = message
	notice_seconds = 4.0
	queue_redraw()


func _draw() -> void:
	if art == null or session == null:
		return
	var rect: Rect2 = art.canvas_rect()
	draw_set_transform(rect.position, 0, Vector2.ONE * (rect.size.x / 1600.0))
	_draw_counters()
	_draw_instruments()
	_draw_status()
	_draw_round_highlights()
	if show_help:
		_draw_help()
	if session.engine.event_pending:
		_draw_event()
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _draw_counters() -> void:
	var engine = session.engine
	_number(Vector2(1408, 847), engine.lignite)
	_number(Vector2(1408, 917), engine.anthracite)
	_number(Vector2(1500, 979), engine.speed)
	var rates := ["OFF", "NORMAL", "FAST"]
	_text(Vector2(462, 723), rates[engine.lignite_rate], 17)
	_text(Vector2(1031, 723), rates[engine.anthracite_rate], 17)
	var brake_text := "BRAKE ON" if engine.brake else "BRAKE OFF"
	_text(Vector2(636, 985), brake_text, 17)


func _number(position: Vector2, value: int) -> void:
	_text(position, str(value), 36)


func _text(position: Vector2, value: String, font_size: int) -> void:
	draw_string(_font, position + Vector2(2, 2), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#090d10"))
	draw_string(_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, GOLD)


func _draw_instruments() -> void:
	var engine = session.engine
	_needle(Vector2(854, 141), float(engine.temperature) / 600.0)
	_needle(Vector2(907, 145), float(engine.pressure_reserve) / 32000.0)
	_needle(Vector2(961, 143), float(engine.speed) / 300.0)
	_text(Vector2(546, 316), "REGULATOR %03d" % engine.regulator, 17)
	var elapsed_minutes: int = engine.cycles * 3
	_text(Vector2(50, 783), "%02d:%02d" % [elapsed_minutes / 60, elapsed_minutes % 60], 17)


func _needle(center: Vector2, ratio: float) -> void:
	var angle := lerpf(-PI * 1.25, PI * 0.25, clampf(ratio, 0, 1))
	draw_line(center, center + Vector2.from_angle(angle) * 12, Color("#ad4a32"), 3.0)
	draw_rect(Rect2(center - Vector2(2, 2), Vector2(4, 4)), PALE)


func _draw_status() -> void:
	var text := "L / A: STOKERS   ARROWS: REGULATOR   B: BRAKE   SPACE: PAUSE   F5 / F6: SAVE / LOAD   H: HELP"
	if not hover_hint.is_empty():
		text = hover_hint
	if hover_id == "gauges":
		text = "BOILER %d   STEAM RESERVE %d   SPEED %d" % [session.engine.temperature, session.engine.pressure_reserve, session.engine.speed]
	if notice_seconds > 0:
		text = notice
	if session.paused:
		text = "PAUSED · Space or click the clock to resume"
	draw_rect(Rect2(260, 12, 1080, 34), Color(0.025, 0.04, 0.055, 0.90))
	_text(Vector2(280, 36), text, 18)
	_text(Vector2(585, 760), "ENGINE ROOM  ·  CALIBRATION PREVIEW", 15)


func _draw_round_highlights() -> void:
	var centers: Array[Vector2] = []
	var radius := 15.0
	if hover_id == "gauges":
		centers = [Vector2(854, 141), Vector2(907, 145), Vector2(961, 143)]
	elif hover_id == "pause":
		centers = [Vector2(127, 890)]
		radius = 87.0
	for center in centers:
		draw_arc(center, radius, 0, TAU, 72, Color(1, 0.81, 0.49, 0.65), 1.0)


func _draw_help() -> void:
	draw_rect(Rect2(370, 330, 860, 348), Color(0.035, 0.055, 0.07, 0.97))
	draw_rect(Rect2(370, 330, 860, 348), GOLD, false, 2)
	var lines := ["THE ENGINE ROOM", "1. Click each stoker to feed the fire: OFF / NORMAL / FAST.", "2. Drag the wheel above the furnace to set the regulator.", "3. Build steam; speed rises when the reserve is sufficient.", "4. Apply the brake with B or the lever in the lower panel.", "Space: pause · F5: save · F6: load · R: restart · Esc: close", "Lignite is also money. Leaving the stokers on spends your reserves.", "M: drive the eastbound trial route · real-time pace is provisional."]
	for index in lines.size():
		_text(Vector2(394, 370 + index * 38), lines[index], 20 if index == 0 else 17)


func _draw_event() -> void:
	draw_rect(Rect2(400, 375, 800, 190), Color(0.04, 0.055, 0.065, 0.97))
	draw_rect(Rect2(400, 375, 800, 190), Color("#c8754d"), false, 2)
	_text(Vector2(430, 425), session.engine.event_message.to_upper(), 26)
	_text(Vector2(430, 468), "Original event reached. Its continuation is not implemented.", 18)
	_text(Vector2(430, 510), "Simulation stopped. F6: load your save · R: restart.", 18)


func _gui_input(event: InputEvent) -> void:
	if session == null or art == null:
		return
	if event is InputEventMouseMotion:
		dragging_regulator = dragging_regulator and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		_pointer_move(art.screen_to_logical(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer_button(event, art.screen_to_logical(event.position))


func _pointer_move(point: Vector2) -> void:
	var previous_state := _visible_state()
	if dragging_regulator:
		_adjust_regulator(point.x)
	hover_id = ""
	hover_hint = ""
	for hotspot in HOTSPOTS:
		if _contains(hotspot, point):
			hover_id = hotspot[0]
			hover_hint = hotspot[2]
			hover_rect = hotspot[1]
			break
	var actor_hover := -1
	if hover_rect.position.y < 760 and hover_id in ["lignite", "anthracite"]:
		actor_hover = 0 if hover_id == "lignite" else 1
	art.set_hovered_stoker(actor_hover)
	art.set_hovered_engineer(hover_id == "regulator")
	var interface_hover := hover_id in ["brake", "journal"]
	art.set_hovered_interface(hover_rect if interface_hover else Rect2())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not hover_id.is_empty() else Control.CURSOR_ARROW
	var state := _visible_state()
	if state != previous_state:
		_last_refresh_state = state
		queue_redraw()


func _pointer_button(event: InputEventMouseButton, point: Vector2) -> void:
	if not event.pressed:
		dragging_regulator = false
		return
	if show_help:
		show_help = false
		return
	for hotspot in HOTSPOTS:
		if _contains(hotspot, point):
			_click_hotspot(hotspot[0], point)
			break
	accept_event()


func _click_hotspot(action: String, point: Vector2) -> void:
	activate(action)
	if action == "regulator":
		dragging_regulator = true
		_adjust_regulator(point.x)


func _contains(hotspot: Array, point: Vector2) -> bool:
	if not hotspot[1].has_point(point):
		return false
	if hotspot[0] == "regulator":
		return art != null and art.is_engineer_pixel(point)
	return true


func _clear_hover() -> void:
	if art != null:
		art.set_hovered_stoker(-1)
		art.set_hovered_engineer(false)
		art.set_hovered_interface(Rect2())
	hover_id = ""
	hover_hint = ""
	queue_redraw()


func _adjust_regulator(x: float) -> void:
	if not session.engine.event_pending:
		session.engine.set_regulator((x - 535.0) / 185.0 * 300.0)


func activate(action: String) -> void:
	if action == "pause":
		session.paused = not session.paused
	elif action == "gauges":
		show_instruments = true
		requested.emit("instruments")
	elif action == "room":
		show_instruments = false
	elif action == "help":
		show_help = not show_help
	elif action in ["map", "journal"]:
		requested.emit(action)
	elif not session.engine.event_pending:
		_activate_engine(action)
	queue_redraw()


func _activate_engine(action: String) -> void:
	match action:
		"lignite":
			session.engine.cycle_lignite()
			announce("Lignite stoker: " + ["OFF", "NORMAL", "FAST"][session.engine.lignite_rate])
		"anthracite":
			session.engine.cycle_anthracite()
			announce("Anthracite stoker: " + ["OFF", "NORMAL", "FAST"][session.engine.anthracite_rate])
		"brake":
			session.engine.toggle_brake()
			announce("Brake applied" if session.engine.brake else "Brake released")
