extends "res://scripts/original_screen.gd"

# MIT. Authored shortcut-settings badge in the unused centre of OPTIONS.
signal requested
const Choice = preload("res://scripts/brass_choice.gd")
const BADGE := Rect2(130,128,59,17) # source: authored layout between original plaques.

func _ready() -> void:
	super._ready()
	mouse_exited.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _draw() -> void:
	if get_parent().loader.visible:
		return
	begin_canvas()
	Choice.draw(self,BADGE,BADGE,"KEYS",has_focus())
	draw_set_transform(Vector2.ZERO)

func _gui_input(event: InputEvent) -> void:
	Choice.refresh(self,event)
	if get_parent().loader.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and BADGE.has_point(logical_point(event.position)):
		requested.emit()
		accept_event()
