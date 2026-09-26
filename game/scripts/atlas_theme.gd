extends RefCounted

# source: tasks/visual-design.md. Authored slate, ice and brass interface palette.
static func create_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 15
	for control in ["Label", "LineEdit", "Button", "ItemList"]:
		result.set_color("font_color", control, Color("#c6d6d9"))
	var panel := _box("#152630", "#3c535d")
	var focus := _box("#152630", "#c5a76a")
	result.set_stylebox("normal", "LineEdit", panel)
	result.set_stylebox("focus", "LineEdit", focus)
	result.set_color("font_placeholder_color", "LineEdit", Color("#829da7"))
	result.set_stylebox("panel", "ItemList", _box("#111f29", "#30464f"))
	var selected := _box("#2b424b", "#bb9c66")
	result.set_stylebox("selected", "ItemList", selected)
	result.set_stylebox("selected_focus", "ItemList", selected)
	result.set_color("font_selected_color", "ItemList", Color("#f4dfb1"))
	result.set_constant("v_separation", "ItemList", 8)
	result.set_stylebox("normal", "Button", panel)
	result.set_stylebox("hover", "Button", _box("#314951", "#b4a47c"))
	result.set_stylebox("pressed", "Button", _box("#1c303b", "#d3ad67"))
	result.set_stylebox("focus", "Button", focus)
	return result


static func _box(background: String, border: String) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(background)
	box.border_color = Color(border)
	box.set_border_width_all(1)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box
