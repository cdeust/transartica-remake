extends "res://scripts/original_screen.gd"

# Original text/death flow: tasks/evidence/boudoir-layout.md, ROOM 0x121, YODA 0x27d8.
signal confirmed
signal dismissed
signal options_requested
var mode := ""
var lines: Array[String] = []
var _earth: Texture2D
var _armed := false
const EPITAPH: Array[String] = [
	"THE CAPTAINS' BODY WAS DISCOVERED IN", "THE MORNING BY HIS SECRETARY KOLOTOV.",
	"THE FACE OF THE DEAD MAN REFLECTED", "THE DESPAIR OF HIS LAST MOMENTS",
	"WHEN HE COULD NOT FULFIL HIS", "RESPONSIBILITIES.",
	"AND THE SUN CONTINUED TO SHINE", "ITS BENEVOLENT RAYS ACROSS THE TOP",
	"OF THE OPAQUE CLOUD LAYER,", "HIDDEN FROM HUMAN EYES."]
const EPITAPH_Y := [17, 34, 49, 64, 79, 94, 109, 124, 139, 154]


func _ready() -> void:
	super._ready()
	if ResourceLoader.exists("res://assets/interface/mort-earth.png"):
		_earth = load("res://assets/interface/mort-earth.png")
	hide()


func prompt_revolver() -> void:
	mode = "confirm"
	lines = ["IN ORDER TO COMMIT SUICIDE", "PRESS THE LEFT BUTTON", "OR THE RIGHT BUTTON TO CANCEL"]
	_open()


func inform(message: Array[String]) -> void:
	mode = "notice"
	lines = message
	_open()


func end_journey() -> void:
	mode = "epitaph"
	_open()


func _open() -> void:
	_armed = false
	show()
	queue_redraw()


func _draw() -> void:
	if mode in ["epitaph", "earth"]:
		frame()
	if mode == "earth" and _earth != null:
		draw_texture_rect(_earth, canvas_rect(), false)
		return
	begin_canvas()
	if mode == "epitaph":
		for index in EPITAPH.size():
			centered(EPITAPH_Y[index], EPITAPH[index])
	else:
		draw_rect(Rect2(0, 159, 320, 41), Color.BLACK)
		draw_rect(Rect2(0, 159, 320, 41), GOLD, false, 0.6)
		for index in lines.size():
			centered(169 + index * 9, lines[index])
	draw_set_transform(Vector2.ZERO)


func advance() -> void:
	if mode == "epitaph":
		mode = "earth"
		queue_redraw()
	elif mode == "earth":
		hide()
		options_requested.emit()
	else:
		hide()
		dismissed.emit()


func handle_key(code: int) -> void:
	if mode == "confirm":
		if code in [KEY_ESCAPE, KEY_F1]:
			hide()
			dismissed.emit()
	elif code in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
		advance()


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if mode == "confirm" and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			confirmed.emit()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			hide()
			dismissed.emit()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_armed = true
		elif _armed:
			_armed = false
			advance()
	accept_event()
