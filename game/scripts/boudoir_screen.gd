extends "res://scripts/original_screen.gd"

# Scene layout: room.alis, tasks/evidence/boudoir-layout.md.
# Hit regions follow the corresponding freshly redrawn objects, never visible boxes.
const InventoryPage = preload("res://scripts/inventory_page.gd")
const SaveBook = preload("res://scripts/save_book.gd")
const Actions = preload("res://scripts/boudoir_actions.gd")
# source: measured object silhouettes in the authored ECS-layout scene texture.
const REGIONS := {10: Rect2(0.03, 0.77, 0.075, 0.17), 11: Rect2(0.10, 0.32, 0.28, 0.66), # source: measured authored scene silhouettes.
	12: Rect2(0.455, 0.79, 0.10, 0.15), 13: Rect2(0.57, 0.74, 0.30, 0.24)} # source: authored revolver and book extents.
const HINTS := {10: "Stoup", 11: "Kolotov", 12: "Revolver", 13: "Save"}
signal requested(panel: String)
signal action_requested(code: int)
var inventory
var book
var _art: Texture2D


func _ready() -> void:
	super._ready()
	_art = load("res://assets/boudoir/captain-boudoir.png")
	inventory = InventoryPage.new()
	inventory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(inventory)
	inventory.closed.connect(close_sheet)
	book = SaveBook.new()
	book.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(book)
	book.closed.connect(close_sheet)
	hide()


func art_rect() -> Rect2:
	var bounds := canvas_rect()
	return Rect2(bounds.position, bounds.size * Vector2(1, 149.0 / 200.0))


func _draw() -> void:
	if _art != null:
		draw_texture_rect(_art, art_rect(), false)


func show_room() -> void:
	close_sheet()
	show()


func close_sheet() -> void:
	inventory.hide()
	book.close_book()


func blocks_simulation() -> bool:
	return visible and (inventory.visible or book.visible)


func activate(code: int) -> void:
	if code in REGIONS:
		action_requested.emit(code)


func hotspot_at(point: Vector2) -> int:
	var bounds := art_rect()
	if not bounds.has_point(point):
		return 0
	var normalized := (point - bounds.position) / bounds.size
	for code in REGIONS:
		if REGIONS[code].has_point(normalized):
			return code
	return 0


func _gui_input(event: InputEvent) -> void:
	if blocks_simulation():
		return
	if event is InputEventMouseMotion:
		var code := hotspot_at(event.position)
		tooltip_text = HINTS.get(code, "")
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if code else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		activate(hotspot_at(event.position))
		accept_event()


func handle_key(event: InputEventKey) -> void:
	if book.visible:
		if event.physical_keycode in [KEY_F1, KEY_ESCAPE]:
			close_sheet()
		return
	if inventory.visible:
		if event.physical_keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
			inventory.next_page()
		return
	match event.physical_keycode:
		KEY_ESCAPE: requested.emit("room")
		KEY_I: activate(Actions.KOLOTOV_CODE)
		KEY_S, KEY_F5: activate(Actions.BOOK_CODE)
		KEY_M: requested.emit("map")


func _has_point(point: Vector2) -> bool:
	var bounds := canvas_rect()
	return Rect2(bounds.position, bounds.size * Vector2(1, 149.0 / 200.0)).has_point(point)
