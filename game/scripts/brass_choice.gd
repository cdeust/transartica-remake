extends RefCounted

# MIT. Owner4Oct readability correction; original art and input bounds retained.
# Palette reuses OriginalScreen.GOLD and WorldEventScreen's dark navy.
const DARK := Color("#0c1d27")
const GOLD := Color("#eeca88")


static func draw(view, bounds: Rect2, hitbox: Rect2, label: String, focused := false) -> void:
	var hovered: bool = hitbox.has_point(view.logical_point(view.get_local_mouse_position()))
	var pressed := hovered and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	view.draw_rect(bounds, DARK.lightened(0.2) if hovered else DARK) # authored hover strength.
	view.draw_rect(bounds, GOLD, false, 2.0 if focused or pressed else 1.0) # logical-pixel frame.
	var factor: float = view.canvas_rect().size.x / view.CANVAS.x
	var pixels := maxi(1, roundi(7 * factor)) # existing OriginalScreen text size.
	var width: float = ThemeDB.fallback_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x/factor
	view.text_at(Vector2(bounds.get_center().x-width*0.5,bounds.end.y-5),label) # authored label inset5px.


static func refresh(view, event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		view.queue_redraw()
