extends Control

# MIT. Logical canvas and text anchors from tasks/evidence/boudoir-layout.md.
const CANVAS := Vector2(320, 200)
const GOLD := Color("#eeca88")
var _frame: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists("res://assets/interface/inventory-frame.png"):
		_frame = load("res://assets/interface/inventory-frame.png")
	resized.connect(queue_redraw)


func canvas_rect() -> Rect2:
	var factor := minf(size.x / CANVAS.x, size.y / CANVAS.y)
	var extent := CANVAS * factor
	return Rect2((size - extent) * 0.5, extent)


func logical_point(point: Vector2) -> Vector2:
	var bounds := canvas_rect()
	return (point - bounds.position) * CANVAS / bounds.size


func begin_canvas() -> void:
	var bounds := canvas_rect()
	draw_set_transform(bounds.position, 0, Vector2.ONE * bounds.size.x / CANVAS.x)


func frame() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if _frame != null:
		draw_texture_rect(_frame, canvas_rect(), false)


func text_at(point: Vector2, value: String, font_size := 7) -> void:
	# Use actual output pixels: magnifying a seven-pixel glyph loses readability.
	var bounds := canvas_rect()
	var factor := bounds.size.x / CANVAS.x
	var pixels := maxi(1, roundi(font_size * factor))
	draw_set_transform(Vector2.ZERO)
	draw_string(ThemeDB.fallback_font, bounds.position + point * factor, value,
		HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, GOLD)
	begin_canvas()


func centered(y: float, value: String, font_size := 7) -> void:
	var factor := canvas_rect().size.x / CANVAS.x
	var pixels := maxi(1, roundi(font_size * factor))
	var width := ThemeDB.fallback_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x / factor
	text_at(Vector2((CANVAS.x - width) * 0.5, y), value, font_size)
