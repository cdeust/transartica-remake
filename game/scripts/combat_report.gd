extends "res://scripts/original_screen.gd"

# source: TEXTEK0x4b13..0x4bd5 full text report; no new dashboard controls.
signal continued
signal options_requested
var result := {}


func _ready() -> void:
	super._ready()
	hide()


func open_report(value: Dictionary) -> void:
	result = value
	show()
	queue_redraw()


func _draw() -> void:
	frame()
	begin_canvas()
	centered(17, "TRAIN COMBAT")
	if result.get("manual", false):
		centered(49, "TACTICAL COMBAT NOT YET AVAILABLE")
		centered(79, "F6: COMBAT OPTIONS")
	else:
		centered(34, "VICTORY" if result.get("won", false) else "TRANSARCTICA HAS BEEN DEFEATED")
		if result.get("won", false):
			centered(64, "%d SOLDIER(S) KILLED" % result.get("soldiers_lost", 0))
			centered(79, "%d MAMMOTH(S) KILLED" % result.get("mammoths_lost", 0))
		centered(154, "PRESS RETURN")
	draw_set_transform(Vector2.ZERO)


func handle_key(event: InputEventKey) -> void:
	if event.physical_keycode == KEY_F6:
		options_requested.emit()
	elif event.physical_keycode in [KEY_ENTER, KEY_SPACE] and not result.get("manual", false):
		hide()
		continued.emit()
