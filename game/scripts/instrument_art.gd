extends RefCounted
# source: generated instruments.png measured composition; manual ENGINE CONTROLS A–F.
const PLATE = preload("res://assets/engine-room/instruments.png")
const GOLD := Color("#e2b975")
const DARK := Color("#18202a")

static func render(canvas: Control, engine) -> void:
	canvas.draw_texture_rect(PLATE, Rect2(0, 0, 1600, 1000), false)
	_needle(canvas, Vector2(338, 527), 146, float(engine.heat) / 5000.0)
	_needle(canvas, Vector2(823, 462), 112, float(engine.speed) / 300.0)
	_label(canvas, Vector2(224, 760), "BOILER PRESSURE", [20, GOLD])
	_label(canvas, Vector2(726, 660), "SPEED · km/h", [22, GOLD])
	_label(canvas, Vector2(751, 529), "%03d" % engine.speed, [32, DARK])
	_label(canvas, Vector2(262, 599), str(engine.heat), [30, DARK])
	_label(canvas, Vector2(235, 632), "LIMIT 5000", [17, DARK])
	_thermometer(canvas, engine.temperature)
	_regulator(canvas, engine.regulator)
	_label(canvas, Vector2(662, 858), "PISTON PRESSURE", [15, GOLD])
	_label(canvas, Vector2(745, 793), "%03d" % (engine.pressure_reserve / 200), [38, GOLD])
	_label(canvas, Vector2(1307, 968), "ENGINE ROOM", [20, GOLD])
	if engine.event_pending:
		_label(canvas, Vector2(380, 956), "BOILER EVENT · F6 LOAD / R RESTART", [24, GOLD])


static func _needle(canvas: Control, center: Vector2, radius: float, ratio: float) -> void:
	# source: authored dial sweep; original overload limit derives from TIME 0xff.
	var angle := PI * 0.75 + clampf(ratio, 0.0, 1.0) * PI * 1.5
	var tip := center + Vector2.from_angle(angle) * radius
	canvas.draw_line(center + Vector2(3, 3), tip + Vector2(3, 3), Color(0, 0, 0, 0.25), 6)
	canvas.draw_line(center, tip, Color("#78372a"), 5)
	canvas.draw_circle(center, 8, GOLD)


static func _thermometer(canvas: Control, temperature: int) -> void:
	# source: TIME temperature clamp600; measured tube bounds in instruments.png.
	var height := 356.0 * clampf(float(temperature) / 600.0, 0.0, 1.0)
	canvas.draw_rect(Rect2(1230, 705 - height, 7, height), Color("#ae4131"))
	_label(canvas, Vector2(1187, 281), "%d °C" % temperature, [23, GOLD])


static func _regulator(canvas: Control, regulator: int) -> void:
	# source: original TRAIN target range0..300; measured slot bounds of new artwork.
	var x := lerpf(500.0, 1100.0, float(regulator) / 300.0)
	canvas.draw_rect(Rect2(x - 12, 132, 24, 71), Color("#3a2520"))
	canvas.draw_rect(Rect2(x - 9, 132, 18, 63), GOLD)
	_label(canvas, Vector2(675, 87), "REGULATOR  %03d" % regulator, [22, GOLD])


static func _label(canvas: Control, at: Vector2, text: String, style: Array) -> void:
	canvas.draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(style[0]), style[1])
