extends Sprite2D

# MIT. Same registered matte and shader contract as engine_room_art.gd.
# Mask paths and contours: tasks/wagon-masks-20261002.md.
var hovered_code := 0
var _masks: Dictionary[int, Texture2D] = {}
var _bounds := Rect2()


func configure(paths: Dictionary) -> void:
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var highlight := ShaderMaterial.new()
	highlight.shader = preload("res://shaders/object_hover.gdshader")
	highlight.set_shader_parameter("coverage_from_alpha", str(paths.values()[0]).ends_with(".png"))
	material = highlight
	for code: int in paths:
		_masks[code] = load(paths[code]) as Texture2D
	clear()


func fit_to(bounds: Rect2) -> void:
	_bounds = bounds
	position = bounds.position
	if texture != null:
		scale = bounds.size / texture.get_size()


func select(code: int) -> void:
	hovered_code = code if _masks.has(code) else 0
	visible = hovered_code != 0
	if visible:
		texture = _masks[hovered_code]
		fit_to(_bounds)


func clear() -> void:
	select(0)
