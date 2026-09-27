extends Control

# source: tasks/evidence/original-visuals.md: ECS banner rows0..38, painting
# rows39..148, common HUD rows149..199. Paintings are existing remake assets.
const FRAME_SIZE := Vector2(320, 200)
const PICTURE := Rect2(0, 39, 320, 110)
const SCENES := {1: "city-information", 2: "city-trading-station", 3: "city-industrial-workshop",
	4: "city-garrison", 5: "city-mammoth-fair", 6: "city-slave-market"}
# source: authored steel/brass styling for the decoded ECS banner structure.
const INK := Color("#0c202a")
const STEEL := Color("#4d8493")
const BRASS := Color("#d8b77b")
var texture: Texture2D
var asset_path := ""
var trading := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_city(kind: int, workshop: bool) -> void:
	var name: String = SCENES.get(3 if workshop else kind, "")
	asset_path = "res://assets/cities/" + name + ".png" if not name.is_empty() else ""
	texture = load(asset_path) as Texture2D if not asset_path.is_empty() else null
	queue_redraw()


func frame_rect() -> Rect2:
	var scale_factor := minf(size.x / FRAME_SIZE.x, size.y / FRAME_SIZE.y)
	var fitted := FRAME_SIZE * scale_factor
	return Rect2((size - fitted) / 2.0, fitted)


func screen_rect(logical: Rect2) -> Rect2:
	var frame := frame_rect()
	var factor := frame.size.x / FRAME_SIZE.x
	return Rect2(frame.position + logical.position * factor, logical.size * factor)


func _draw() -> void:
	var scene := screen_rect(PICTURE)
	draw_rect(screen_rect(Rect2(0, 0, 320, 149)), INK)
	if texture != null and scene.has_area():
		# Fill the original scene band without stretching. Existing paintings have
		# differing aspect ratios: crop symmetrically, never alter the source files.
		var source_size := texture.get_size()
		var factor := maxf(scene.size.x / source_size.x, scene.size.y / source_size.y)
		var crop_size := scene.size / factor
		draw_texture_rect_region(texture, scene, Rect2((source_size - crop_size) / 2.0, crop_size))
	if trading:
		draw_rect(scene, Color(0.025, 0.065, 0.085, 0.92))
	var banner := screen_rect(Rect2(1, 1, 318, 19))
	draw_style_box(border(INK, STEEL), banner)


static func border(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	return style


static func interface_theme(font_size: int) -> Theme:
	var result := Theme.new()
	result.default_font_size = font_size
	result.set_color("font_color", "Label", Color("#f0e3cb"))
	result.set_color("font_color", "Button", Color("#fff0d4"))
	result.set_stylebox("normal", "Button", border(Color("#3a3025"), BRASS))
	result.set_stylebox("hover", "Button", border(Color("#574632"), BRASS))
	result.set_stylebox("pressed", "Button", border(Color("#231e19"), BRASS))
	result.set_stylebox("panel", "ItemList", border(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	result.set_stylebox("selected", "ItemList", border(Color("#4a4537"), BRASS))
	return result
