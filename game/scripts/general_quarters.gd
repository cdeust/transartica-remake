extends "res://scripts/original_screen.gd"

# TRAIN GQ actions at 0xe19. Coordinates follow the authored ECS-layout redraw.
signal action_requested(code: int)
const Hover = preload("res://scripts/wagon_hover.gd")
const MASKS := {
	10: "res://assets/boudoir/cutouts/quarters-stoup.png",
	11: "res://assets/boudoir/cutouts/quarters-operator.png",
	12: "res://assets/boudoir/cutouts/quarters-map.png",
	13: "res://assets/boudoir/cutouts/quarters-officer.png",
}
var _art: Texture2D
var hover_layer: Hover
# source: measured object silhouettes in the authored ECS-layout scene texture.
const REGIONS := {10: Rect2(0, 0.74, 0.085, 0.24), 11: Rect2(0.08, 0.44, 0.13, 0.49), # source: measured authored scene silhouettes.
	13: Rect2(0.80, 0.20, 0.20, 0.80), 12: Rect2(0.36, 0.4, 0.44, 0.6)}


func _ready() -> void:
	super._ready()
	if ResourceLoader.exists("res://assets/boudoir/general-quarters.png"):
		_art = load("res://assets/boudoir/general-quarters.png")
	hover_layer = Hover.new()
	hover_layer.configure(MASKS)
	add_child(hover_layer)
	mouse_exited.connect(hover_layer.clear)
	visibility_changed.connect(hover_layer.clear)
	hide()


func _draw() -> void:
	var bounds := canvas_rect()
	if _art != null:
		draw_texture_rect(_art, Rect2(bounds.position, bounds.size * Vector2(1, 149.0 / 200.0)), false)
	if hover_layer != null:
		hover_layer.fit_to(Rect2(bounds.position, bounds.size * Vector2(1, 149.0 / 200.0)))


func _gui_input(event: InputEvent) -> void:
	var point: Vector2 = logical_point(event.position) / Vector2(320, 149) if event is InputEventMouse else Vector2(-1, -1)
	var hovered := 0
	for code in REGIONS:
		if REGIONS[code].has_point(point):
			hovered = code
			break
	if event is InputEventMouseMotion:
		hover_layer.select(hovered)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and hovered:
		hover_layer.clear()
		action_requested.emit(hovered)
		accept_event()


func _has_point(point: Vector2) -> bool:
	var bounds := canvas_rect()
	return Rect2(bounds.position, bounds.size * Vector2(1, 149.0 / 200.0)).has_point(point)
