extends "res://scripts/original_screen.gd"

# MIT. Explicit remake settings; original OPTIONS plaques keep their roles.
const Bindings = preload("res://scripts/key_bindings.gd")
const LABELS := ["LIGNITE","ANTHRACITE","BRAKE","PAUSE","HELP","MAP",
	"JOURNAL","REGULATOR -","REGULATOR +","SAVE","OPTIONS","NEW GAME"]
var bindings = Bindings.new()
var selected := ""
var notice := "SELECT A COMMAND, THEN PRESS ITS NEW KEY"

static func attach(app) -> void:
	var control = load("res://scripts/keyboard_settings.gd").new()
	control.name = "KeyboardSettings"
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.add_child(control)
	control.bindings.load_settings(app._save_path().get_base_dir().path_join("keyboard.cfg"))
	app.room_controls.bindings = control.bindings
	var launcher = preload("res://scripts/keyboard_settings_button.gd").new()
	app._boudoir_session.reception.add_child(launcher)
	launcher.requested.connect(control.open)

func _ready() -> void:
	super._ready()
	hide()

func open() -> void:
	selected = ""
	notice = "SELECT A COMMAND, THEN PRESS ITS NEW KEY"
	get_parent().move_child(self,get_parent().get_child_count()-1)
	show()
	queue_redraw()

func row(index: int) -> Rect2:
	# Authored two-column layout inside the existing inventory art frame.
	return Rect2(15+(index/6)*155,45+(index%6)*19,140,17)

func _draw() -> void:
	frame()
	begin_canvas()
	centered(29,"KEYBOARD SHORTCUTS",9)
	var actions: Array = Bindings.DEFAULTS.keys()
	for index in actions.size():
		var bounds := row(index)
		if selected == actions[index]:
			draw_rect(bounds,Color("#42392b"))
		text_at(bounds.position+Vector2(2,7),LABELS[index])
		text_at(bounds.position+Vector2(2,15),OS.get_keycode_string(bindings.keys[actions[index]]))
	centered(168,notice,6)
	text_at(Vector2(20,187),"RESTORE DEFAULTS")
	text_at(Vector2(268,187),"EXIT")
	draw_set_transform(Vector2.ZERO)

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE:
		if selected.is_empty():
			hide()
		else:
			selected = ""
	elif not selected.is_empty():
		if bindings.assign(selected,event.physical_keycode):
			notice = "SAVED"
			selected = ""
		else:
			notice = "KEY ALREADY USED OR SETTINGS COULD NOT BE SAVED"
	queue_redraw()
	get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var point := logical_point(event.position)
	for index in Bindings.DEFAULTS.size():
		if row(index).has_point(point):
			selected = Bindings.DEFAULTS.keys()[index]
	if Rect2(15,176,125,20).has_point(point):
		notice = "DEFAULTS RESTORED" if bindings.defaults() else "COULD NOT SAVE SETTINGS"
		selected = ""
	if Rect2(260,176,45,20).has_point(point):
		hide()
	queue_redraw()
	accept_event()
