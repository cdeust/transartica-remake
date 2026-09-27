extends "res://scripts/original_screen.gd"

# OPTION resource15: same five-plaque screen, original loading outside the book.
const SaveBook = preload("res://scripts/save_book.gd")
signal start_requested
signal load_requested(slot_name: String)
signal unavailable_requested
var loader
var directory := ""
var _art: Texture2D
# source: resource0 plaque centres and 128x68 dimensions, boudoir-layout.md.
const PLAQUES := {"start": Rect2(95, 50, 128, 68), "load": Rect2(191, 126, 128, 68),
	"level": Rect2(0, 0, 128, 68), "combat": Rect2(191, 0, 128, 68), "music": Rect2(0, 126, 128, 68)}


func _ready() -> void:
	super._ready()
	if ResourceLoader.exists("res://assets/interface/reception.png"):
		_art = load("res://assets/interface/reception.png")
	loader = SaveBook.new()
	loader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(loader)
	loader.closed.connect(loader.close_book)
	loader.load_requested.connect(func(slot_name): load_requested.emit(slot_name))
	hide()


func open_options(save_directory: String) -> void:
	directory = save_directory
	loader.close_book()
	show()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if _art != null:
		draw_texture_rect(_art, canvas_rect(), false)


func handle_key(event: InputEventKey) -> void:
	if loader.visible:
		if event.physical_keycode in [KEY_F1, KEY_ESCAPE]:
			loader.close_book()
	elif event.physical_keycode == KEY_ENTER:
		start_requested.emit()


func _gui_input(event: InputEvent) -> void:
	if loader.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var point := logical_point(event.position)
		for action in PLAQUES:
			if PLAQUES[action].has_point(point):
				if action == "start":
					start_requested.emit()
				elif action == "load":
					loader.open_book(directory, true)
				else:
					unavailable_requested.emit()
				accept_event()
				return
