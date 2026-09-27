extends "res://scripts/original_screen.gd"

# ROOM 0x055e: in-game save name on bottom black strip; OPTION load uses full frame.
const Slots = preload("res://scripts/save_slots.gd")
signal closed
signal save_requested(slot_name: String)
signal load_requested(slot_name: String)
var directory := ""
var name_input: LineEdit
var status := ""
var loading := false


func _ready() -> void:
	super._ready()
	name_input = LineEdit.new()
	name_input.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_input.add_theme_color_override("font_color", GOLD)
	name_input.add_theme_color_override("caret_color", GOLD)
	name_input.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	name_input.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	name_input.text_changed.connect(_name_changed)
	name_input.text_submitted.connect(func(_value): submit())
	add_child(name_input)
	resized.connect(_layout)
	hide()


func open_book(save_directory: String, for_loading := false) -> void:
	directory = save_directory
	loading = for_loading
	name_input.text = ""
	status = ""
	_layout()
	show()
	call_deferred("_focus_name")
	queue_redraw()


func _name_changed(value: String) -> void:
	var normalized: String = Slots.normalize_name(value)
	if normalized != value:
		var caret := name_input.caret_column
		name_input.text = normalized
		name_input.caret_column = mini(caret, normalized.length())
	status = ""
	queue_redraw()


func submit() -> void:
	if Slots.slot_path(directory, name_input.text).is_empty():
		return
	if loading:
		load_requested.emit(name_input.text)
	else:
		save_requested.emit(name_input.text)


func show_result(message: String) -> void:
	status = message
	queue_redraw()


func close_book() -> void:
	name_input.release_focus()
	hide()


func _layout() -> void:
	var bounds := canvas_rect()
	var factor := bounds.size.x / CANVAS.x
	var pixels := maxi(1, roundi(7 * factor))
	name_input.add_theme_font_size_override("font_size", pixels)
	name_input.size = Vector2(64, 11) * factor
	# Align the LineEdit centered font box to the same baseline as the suffix.
	var font := name_input.get_theme_font("font")
	var baseline := (109 if loading else 183) * factor
	var ascent := font.get_ascent(pixels)
	var padding := (name_input.size.y - font.get_height(pixels)) / 2.0
	name_input.position = bounds.position + Vector2(135 * factor, baseline - ascent - padding)
	queue_redraw()


func _draw() -> void:
	if loading:
		frame()
	begin_canvas()
	if not loading:
		draw_rect(Rect2(0, 159, 320, 41), Color.BLACK)
		draw_rect(Rect2(0, 159, 320, 41), GOLD, false, 0.6)
	var top := 69 if loading else 167
	centered(top, "ENTER THE NAME OF YOUR BACKUP")
	centered(top + (20 if loading else 8), "THEN PRESS RETURN:")
	centered(129 if loading else 191, status if not status.is_empty() else "TO CANCEL TYPE F1")
	text_at(Vector2(121, 109 if loading else 183), "(")
	var factor := canvas_rect().size.x / CANVAS.x
	var pixels := maxi(1, roundi(7 * factor))
	var width := ThemeDB.fallback_font.get_string_size(name_input.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x / factor
	text_at(Vector2(135 + width, 109 if loading else 183), ".SAV )")
	draw_set_transform(Vector2.ZERO)


func _focus_name() -> void:
	if not visible:
		return
	name_input.grab_focus()
	name_input.edit()
