extends Control
class_name EngineRoomArt

const LOGICAL_SIZE := Vector2(1600.0, 1000.0) # source: tasks/visual-design.md, authored composition grid.
const BACKGROUND_PATH := "res://assets/engine-room/background.png"
const STOKERS_PATH := "res://assets/engine-room/stokers.png"
const FIRE_PATH := "res://assets/engine-room/fire.png"
const STOKER_REGIONS := [
	Rect2(0, 0, 384, 512), Rect2(384, 0, 396, 512),
	Rect2(780, 0, 360, 512), Rect2(1140, 0, 396, 512),
	Rect2(0, 512, 340, 512), Rect2(340, 512, 400, 512),
	Rect2(740, 512, 380, 512), Rect2(1120, 512, 416, 512),
]
const STOKER_PIVOTS := [
	Vector2(177, 481), Vector2(560, 481), Vector2(905, 481), Vector2(1262, 481),
	Vector2(197, 953), Vector2(606, 953), Vector2(948, 953), Vector2(1360, 953),
]
const ACTOR_POSITIONS := [Vector2(550, 724), Vector2(1080, 724)] # source: tasks/visual-design.md composition.
const ACTOR_SCALE := 0.70 # source: authored composition scale around the fire opening.
const FIRE_OPENING := Rect2(665, 495, 270, 180) # source: supplied asset composition, not a measured dimension.
const FIRE_GRID := Vector2i(2, 2) # source: provided fire spritesheet layout.
const FIRE_HEAT_REFERENCE := 600.0 # source: locomotive-rules.md boiler display clamp; visual saturation only.

var engine
var paused := false
var _background: Texture2D
var _stokers: Texture2D
var _fire: Texture2D
var _visual_time := 0.0
var _actor_layer: Node2D
var _actor_nodes: Array[Sprite2D] = []
var _hovered_stoker := -1
var _last_visual_state: Array = []
var _engineer_overlay: Sprite2D
var _engineer_mask: Image
var _interface_overlay: Sprite2D
var living = preload("res://scripts/engine_living_effects.gd").new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background = _load_texture(BACKGROUND_PATH)
	_stokers = _load_texture(STOKERS_PATH)
	_fire = _load_texture(FIRE_PATH)
	_build_actors()
	_build_engineer_overlay()
	_build_interface_overlay()
	resized.connect(_update_actors)
	_update_actors()
	queue_redraw()


func advance_visual(delta: float) -> void:
	if not paused and is_finite(delta) and delta > 0.0:
		_visual_time += delta
		living.advance(delta,engine)
	var state := [_visual_time, engine.heat, engine.pressure_reserve, engine.lignite_rate, engine.anthracite_rate, size]
	if state == _last_visual_state:
		return
	_last_visual_state = state
	_update_actors()
	queue_redraw()


func canvas_rect() -> Rect2:
	var scale := minf(size.x / LOGICAL_SIZE.x, size.y / LOGICAL_SIZE.y)
	var fitted := LOGICAL_SIZE * maxf(scale, 0.0)
	return Rect2((size - fitted) * 0.5, fitted)


func logical_to_screen(point: Vector2) -> Vector2:
	var fitted := canvas_rect()
	return fitted.position + point * (fitted.size / LOGICAL_SIZE)


func screen_to_logical(point: Vector2) -> Vector2:
	var fitted := canvas_rect()
	if fitted.size.x <= 0.0 or fitted.size.y <= 0.0:
		return Vector2.ZERO
	return (point - fitted.position) * (LOGICAL_SIZE / fitted.size)


func _draw() -> void:
	var fitted := canvas_rect()
	if fitted.size.x <= 0.0 or fitted.size.y <= 0.0:
		return
	var scale := fitted.size.x / LOGICAL_SIZE.x
	draw_set_transform(fitted.position, 0.0, Vector2.ONE * scale)
	_draw_background()
	_draw_fire()
	living.draw(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_background() -> void:
	if _background != null:
		draw_texture_rect(_background, Rect2(Vector2.ZERO, LOGICAL_SIZE), false)


func _draw_fire() -> void:
	if _fire == null or engine == null or engine.heat <= 0:
		return
	var frame := _fire_frame()
	var frame_size := Vector2(_fire.get_size()) / Vector2(FIRE_GRID)
	var source := Rect2(Vector2(frame % 2, frame / 2) * frame_size, frame_size)
	var strength := clampf(float(engine.heat) / FIRE_HEAT_REFERENCE, 0.08, 1.0)
	var target := _fire_target(strength)
	draw_texture_rect_region(_fire, target, source, Color(1.0, 1.0, 1.0, strength))


func _fire_frame() -> int:
	return int(_visual_time * 8.0) % 4 # Authored eight-frame-per-second fire loop.


func _fire_target(strength: float) -> Rect2:
	var height := FIRE_OPENING.size.y * (0.25 + 0.75 * strength)
	return Rect2(FIRE_OPENING.position.x, FIRE_OPENING.end.y - height, FIRE_OPENING.size.x, height)


func _build_actors() -> void:
	_actor_layer = Node2D.new()
	add_child(_actor_layer)
	for side in 2:
		var actor := Sprite2D.new()
		actor.texture = _stokers
		actor.centered = false
		actor.region_enabled = true
		actor.region_filter_clip_enabled = true
		var shader_material := ShaderMaterial.new()
		shader_material.shader = load("res://shaders/stoker_hover.gdshader")
		actor.material = shader_material
		_actor_layer.add_child(actor)
		_actor_nodes.append(actor)


func _build_engineer_overlay() -> void:
	_engineer_overlay = Sprite2D.new()
	_engineer_overlay.centered = false
	_engineer_overlay.texture = load("res://assets/engine-room/engineer-mask.png")
	_engineer_mask = _engineer_overlay.texture.get_image()
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load("res://shaders/object_hover.gdshader")
	_engineer_overlay.material = shader_material
	_engineer_overlay.visible = false
	add_child(_engineer_overlay)


func _build_interface_overlay() -> void:
	_interface_overlay = Sprite2D.new()
	_interface_overlay.centered = false
	_interface_overlay.texture = load("res://assets/engine-room/interface-mask.png")
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load("res://shaders/object_hover.gdshader")
	_interface_overlay.material = shader_material
	_interface_overlay.visible = false
	add_child(_interface_overlay)


func set_hovered_interface(region: Rect2) -> void:
	if _interface_overlay == null:
		return
	_interface_overlay.visible = region.has_area()
	var first := region.position / LOGICAL_SIZE
	var last := region.end / LOGICAL_SIZE
	_interface_overlay.material.set_shader_parameter("clip_bounds", Vector4(first.x, first.y, last.x, last.y))


func set_hovered_engineer(active: bool) -> void:
	if _engineer_overlay != null:
		_engineer_overlay.visible = active


func is_engineer_pixel(point: Vector2) -> bool:
	if _engineer_mask == null or not Rect2(Vector2.ZERO, LOGICAL_SIZE).has_point(point):
		return false
	var pixel := Vector2i(point * Vector2(_engineer_mask.get_size()) / LOGICAL_SIZE)
	return _engineer_mask.get_pixelv(pixel).r > 0.5 # Binary white selection matte.


func _update_actors() -> void:
	if _actor_layer == null or _stokers == null:
		return
	var fitted := canvas_rect()
	if _engineer_overlay != null:
		_engineer_overlay.position = fitted.position
		_engineer_overlay.scale = fitted.size / Vector2(_engineer_overlay.texture.get_size())
	if _interface_overlay != null:
		_interface_overlay.position = fitted.position
		_interface_overlay.scale = fitted.size / Vector2(_interface_overlay.texture.get_size())
	_actor_layer.position = fitted.position
	_actor_layer.scale = Vector2.ONE * (fitted.size.x / LOGICAL_SIZE.x)
	for side in _actor_nodes.size():
		_update_stoker(_stoker_frame(side), side)


func set_hovered_stoker(side: int) -> void:
	if side == _hovered_stoker:
		return
	_hovered_stoker = side
	_update_actors()


func _stoker_frame(side: int) -> int:
	var rate := _fuel_rate(side)
	if rate == 0:
		return 0
	var pose_rate := float(rate) * 4.0 # Four authored poses per normal loading cycle.
	return int(floor(_visual_time * pose_rate)) % 4


func _fuel_rate(side: int) -> int:
	if engine == null:
		return 0
	return int(engine.lignite_rate if side == 0 else engine.anthracite_rate)


func _update_stoker(frame: int, side: int) -> void:
	var pose := side * 4 + frame
	var source: Rect2 = STOKER_REGIONS[pose]
	var pivot: Vector2 = STOKER_PIVOTS[pose] - source.position
	var actor: Sprite2D = _actor_nodes[side]
	actor.position = ACTOR_POSITIONS[side] - pivot * ACTOR_SCALE
	actor.scale = Vector2.ONE * ACTOR_SCALE
	actor.region_rect = source
	var tex_size := Vector2(_stokers.get_size())
	var bounds := Vector4(source.position.x / tex_size.x, source.position.y / tex_size.y, source.end.x / tex_size.x, source.end.y / tex_size.y)
	actor.material.set_shader_parameter("frame_uv", bounds)
	actor.material.set_shader_parameter("highlighted", side == _hovered_stoker)


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
