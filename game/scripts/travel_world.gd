extends "res://scripts/world_view.gd"
class_name TravelWorldView

const ICE_FIELD_PATH := "res://assets/travel/ice-field.png"
const GROUND_SHADER_PATH := "res://shaders/travel_ground.gdshader"
const RailNetworkScript = preload("res://scripts/rail_network.gd")
const TRAVEL_MIN_ZOOM := 0.001 # source: authored inspection floor permits complete long consists in a 320px viewport.
const TRAVEL_MAX_ZOOM := 2.0 # source: authored viewport inspection choice.
# Source: map-orientation-audit.md, original CARTE16×16 axes. The authored
# enlargement preserves the previous east-axis length, hence vehicle pixels.
const CELL_PIXELS := sqrt(180.0 * 180.0 + 100.0 * 100.0)
const WORLD_EAST := Vector2(CELL_PIXELS, 0.0)
const WORLD_SOUTH := Vector2(0.0, CELL_PIXELS)
const TRACK_DARK := Color("#202a2c") # source: authored steel-and-ice rail palette.
const TRACK_METAL := Color("#657b87") # source: authored steel highlight.
const TRACK_SNOW := Color("#829ba9") # source: authored snow-edge palette.
const CITY_MARK := Color("#d8b878") # source: authored discovered-city marker.
const TRAIN_NOSE_SCREEN := Vector2(0.72, 0.65) # source: authored framing keeps the full train in view.
const SWITCH_ACTIVE := Color("#e8c46a") # source: authored: branch currently selected by a switch.
const SWITCH_IDLE := Color("#4a5a60") # source: authored: unused branch.

var encounters
var wagons
var map_entities = preload("res://scripts/map_entities.gd").new()
var inspecting_map := false
var camera_world := Vector2(12.5, 62.5)
var session
var network # RailNetwork: live tiles with TABLE writes and switch positions.
signal switch_toggled(cell: Vector2i)
var _visual_from := Vector2.ZERO
var _visual_to := Vector2.ZERO
var _visual_position := Vector2.ZERO
var _visual_elapsed := 0.0
var _visual_initialized := false
var _interpolating := false
var _ice_field: Texture2D
var consist = preload("res://scripts/train_consist.gd").new()
var train_renderer = preload("res://scripts/train_renderer.gd").new()
var _visual_arc := 0.0
var _arc_from := 0.0
var _arc_to := 0.0
var _ground: TextureRect
var _ground_material: ShaderMaterial
var _discovery_mask: ImageTexture


func _ready() -> void:
	# CARTE draws fixed terrain and towns independently of mobile perception.
	discovery_enabled = false
	super._ready()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ice_field = _load_texture(ICE_FIELD_PATH)
	if not train_renderer.load_assets():
		push_error("Vehicle perspective atlas failed to load")
	_setup_ground()
	resized.connect(_update_ground_shader)
	set_process(true)


func _setup_ground() -> void:
	_ground = TextureRect.new()
	_ground.name = "WorldGround"
	_ground.texture = _ice_field
	_ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ground.stretch_mode = TextureRect.STRETCH_SCALE
	_ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground.show_behind_parent = true
	_ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ground)
	if ResourceLoader.exists(GROUND_SHADER_PATH):
		_ground_material = ShaderMaterial.new()
		_ground_material.shader = load(GROUND_SHADER_PATH) as Shader
		_ground_material.set_shader_parameter("ice_texture", _ice_field)
		_ground.material = _ground_material
	_refresh_discovery_mask()
	_update_ground_shader()


func _refresh_discovery_mask() -> void:
	var image := Image.create(WorldDataScript.MAP_WIDTH, WorldDataScript.MAP_HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	for x in WorldDataScript.MAP_WIDTH:
		for y in WorldDataScript.MAP_HEIGHT:
			if not discovery_enabled or discovery.is_discovered(x, y):
				image.set_pixel(x, y, Color.WHITE)
	_discovery_mask = ImageTexture.create_from_image(image)
	if _ground_material != null:
		_ground_material.set_shader_parameter("discovery_mask", _discovery_mask)


func _update_ground_shader() -> void:
	if _ground_material == null:
		return
	_ground_material.set_shader_parameter("view_size", size)
	_ground_material.set_shader_parameter("camera_world", camera_world)
	_ground_material.set_shader_parameter("camera_offset", offset)
	_ground_material.set_shader_parameter("zoom_level", _effective_zoom())
	_ground_material.set_shader_parameter("cell_pixels", CELL_PIXELS)
	_ground_material.set_shader_parameter("discovery_mask", _discovery_mask)
	_ground_material.set_shader_parameter("ice_texture", _ice_field)


# Explicit initial/manual calibration only; movement never invokes this method.
func fit_complete_consist() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	zoom = clampf(preload("res://scripts/train_camera_fit.gd").initial_zoom(self), TRAVEL_MIN_ZOOM, TRAVEL_MAX_ZOOM)
	following_train = false
	center_on_train()
	_update_ground_shader()


func fit_world() -> void:
	_fit_bounds(Rect2i(0, 0, WorldDataScript.MAP_WIDTH, WorldDataScript.MAP_HEIGHT))
	_refresh_discovery_mask()


func fit_discovered() -> void:
	_refresh_discovery_mask()
	var bounds: Rect2i = discovery.discovered_bounds()
	if bounds.size != Vector2i.ZERO:
		_fit_bounds(bounds)


func visit_cell(position: Vector2i) -> bool:
	var previous: Vector2i = discovery.current_position
	var visited: bool = super.visit_cell(position)
	if visited and previous != position:
		_refresh_discovery_mask()
	return visited


func _fit_bounds(bounds: Rect2i) -> void:
	var projected := preload("res://scripts/train_camera_fit.gd").projected_bounds(self, bounds)
	var extent := Vector2(maxf(projected.size.x, 1.0), maxf(projected.size.y, 1.0))
	zoom = clampf(minf(size.x / extent.x, size.y / extent.y) * 0.9, TRAVEL_MIN_ZOOM, TRAVEL_MAX_ZOOM)
	camera_world = (Vector2(bounds.position) + Vector2(bounds.end)) * 0.5
	offset = Vector2.ZERO
	following_train = false
	queue_redraw()


func zoom_by(factor: float, anchor: Vector2 = Vector2.ZERO) -> void:
	if not is_finite(factor) or factor <= 0.0: # source: reject invalid zoom requests before projection inversion.
		return
	var next_zoom := clampf(_effective_zoom() * factor, TRAVEL_MIN_ZOOM, TRAVEL_MAX_ZOOM)
	if is_equal_approx(next_zoom, _effective_zoom()):
		return
	var anchor_world := _screen_to_world(anchor)
	zoom = next_zoom
	offset = anchor - size * 0.5 - (_project(anchor_world) - _project(camera_world)) * zoom
	queue_redraw()


func focus_city(index: int) -> void:
	if world_data == null or index < 0 or index >= world_data.cities.size():
		return
	var city: Dictionary = world_data.cities[index]
	if not _city_is_visible(city):
		return
	selected_city = index
	camera_world = Vector2(float(city.x) + 0.5, float(city.y) + 0.5)
	offset = Vector2.ZERO
	following_train = false
	zoom = _effective_zoom()
	queue_redraw()


func _draw() -> void:
	_update_ground_shader()
	_draw_rails()
	map_entities.draw(self)
	_draw_train()
	map_entities.draw_player_heading(self)


func _draw_rails() -> void:
	if world_data == null:
		return
	var cells := _visible_world_bounds()
	for x in range(maxi(0, cells.position.x), mini(WorldDataScript.MAP_WIDTH, cells.end.x)):
		for y in range(maxi(0, cells.position.y), mini(WorldDataScript.MAP_HEIGHT, cells.end.y)):
			if not _cell_is_visible(x, y):
				continue
			_draw_rail_tile(x, y)


func _tile_code(x: int, y: int) -> int:
	if network != null and network.is_loaded():
		return network.tile(Vector2i(x, y))
	return world_data.map_code(x, y)


func _draw_rail_tile(x: int, y: int) -> void:
	var code: int = _tile_code(x, y)
	var ports: Array[Vector2] = RailGlyphsScript.ports_for_code(code)
	if ports.is_empty():
		if code > 0:
			map_entities.draw_city_tile(self, Vector2i(x, y), code)
		return
	var center := _world_to_screen(Vector2(x + 0.5, y + 0.5))
	for port in ports:
		var world_port := Vector2(x + 0.5, y + 0.5) + port
		_draw_rail_segment(center, _world_to_screen(world_port))
	if ports.size() == 3 and code >= 18 and code <= 33:
		_draw_switch_state(x, y, code, ports, center)


# Straight ports are [0] and [1]; [2] diverges (rail_glyphs.gd). Even code = straight,
# odd = diverging (TIME 0x168c..0x1913, CARTE 0x1253).
func _draw_switch_state(x: int, y: int, code: int, ports: Array[Vector2], center: Vector2) -> void:
	var scale := _effective_zoom()
	var base: int = code - code % 2
	var facing: int = RailNetworkScript.SWITCH_RULES[base][0]
	var entry: Vector2 = -Vector2(RailNetworkScript.DELTAS[facing]) * 0.5
	var active: Array[Vector2] = []
	active.assign([entry, ports[2]] if code % 2 == 1 else [ports[0], ports[1]])
	for port in ports:
		var endpoint := _world_to_screen(Vector2(x + 0.5, y + 0.5) + port * 0.7)
		draw_line(center, endpoint, SWITCH_ACTIVE if port in active else SWITCH_IDLE, maxf(2.0, 7.0 * scale), true)
	draw_circle(center, maxf(4.0, 12.0 * scale), Color("#1c262a"))
	draw_circle(center, maxf(3.0, 8.0 * scale), SWITCH_ACTIVE)


func _draw_rail_segment(start: Vector2, finish: Vector2) -> void:
	var delta := finish - start
	var distance := delta.length()
	if distance <= 1.0:
		return
	var direction := delta / distance
	var side := Vector2(-direction.y, direction.x)
	var scale := _effective_zoom()
	draw_line(start, finish, TRACK_SNOW, 32.0 * scale, true)
	draw_line(start, finish, Color("#34454c"), 26.0 * scale, true)
	_draw_sleepers(start, direction, side, distance, scale)
	_draw_rails_pair(start, finish, side, scale)


func _draw_sleepers(start: Vector2, direction: Vector2, side: Vector2, distance: float, scale: float) -> void:
	var spacing := 16.0 * scale
	for travel in range(0, int(distance), maxi(1, int(spacing))):
		var center := start + direction * float(travel)
		draw_line(center - side * 8.0 * scale, center + side * 8.0 * scale, TRACK_DARK, 4.0 * scale, true)


func _draw_rails_pair(start: Vector2, finish: Vector2, side: Vector2, scale: float) -> void:
	for sign_value in [-1.0, 1.0]:
		var side_sign: float = sign_value
		var rail_offset := side * 10.0 * scale * side_sign
		draw_line(start + rail_offset, finish + rail_offset, TRACK_DARK, 3.0 * scale, true)
		draw_line(start + rail_offset, finish + rail_offset, TRACK_METAL, 1.1 * scale, true)


func _draw_train() -> void:
	if journey == null:
		return
	var lag := maxf(0.0, journey.distance_travelled() - _visual_arc) if _visual_initialized else 0.0
	train_renderer.draw(self, journey, consist, lag)


func _city_screen_point(city: Dictionary) -> Vector2:
	return _world_to_screen(Vector2(float(city.x) + 0.5, float(city.y) + 0.5))


func _city_at(point: Vector2) -> int:
	if world_data == null:
		return -1
	var nearest := -1
	var nearest_distance := CITY_HIT_RADIUS
	for index in world_data.cities.size():
		var city: Dictionary = world_data.cities[index]
		if not _city_is_visible(city):
			continue
		var distance := point.distance_to(_city_screen_point(city))
		if distance <= nearest_distance:
			nearest = index
			nearest_distance = distance
	return nearest


func follow_train() -> void:
	inspecting_map = false
	following_train = true
	update_train()
	queue_redraw()


func update_train() -> void:
	var actual := _current_journey_position()
	var arc: float = journey.distance_travelled() if journey != null else 0.0
	var moved := not _visual_initialized or not is_equal_approx(_arc_to, arc)
	var reset_or_jump: bool = (journey != null and journey.reverse) or not _visual_initialized or arc < _arc_to or _visual_to.distance_to(actual) > 1.5
	if reset_or_jump:
		_snap_visual_position(actual)
	elif moved:
		_visual_from = _visual_position
		_visual_to = actual
		_arc_from = _visual_arc
		_arc_to = arc
		_visual_elapsed = 0.0
		_interpolating = true
	_reveal_occupied_track()
	if following_train:
		_position_camera(_visual_position)
	else:
		_keep_train_in_view()
	if moved:
		queue_redraw()


func _reveal_occupied_track() -> void:
	if journey == null:
		return
	var changed := false
	for vehicle in train_renderer.poses(self, journey, consist, 0.0):
		for point in [vehicle.front, vehicle.center, vehicle.rear]:
			var cell := Vector2i((point + Vector2(0.5, 0.5)).floor())
			changed = discovery.observe_cell(cell) or changed
	if changed:
		_refresh_discovery_mask()


func _process(delta: float) -> void:
	if not _interpolating or not _can_animate() or delta <= 0.0:
		return
	var duration := _cycle_duration()
	if duration <= 0.0:
		return
	_visual_elapsed = minf(_visual_elapsed + delta, duration)
	_visual_arc = lerpf(_arc_from, _arc_to, _visual_elapsed / duration)
	var sample: Dictionary = journey.sample_behind(maxf(0.0, journey.distance_travelled() - _visual_arc))
	if sample.ok:
		_visual_position = sample.position
	_interpolating = _visual_elapsed < duration
	if following_train:
		_position_camera(_visual_position)
	else:
		_keep_train_in_view()
	queue_redraw()


func center_on_train() -> void:
	inspecting_map = false
	_center_camera(_visual_position if _visual_initialized else _current_journey_position())
	_keep_train_in_view()
	queue_redraw()


func _center_camera(position: Vector2) -> void:
	var middle := position
	if journey != null:
		var lag := maxf(0.0, journey.distance_travelled() - _visual_arc) if _visual_initialized else 0.0
		var sample: Dictionary = journey.sample_behind(consist.length_world() * train_renderer.WAGON_CELL_RATIO * 0.5 + lag)
		if sample.ok:
			middle = sample.position
	camera_world = middle + Vector2(0.5, 0.5)
	offset = Vector2.ZERO
	zoom = _effective_zoom()


# Fixed camera: recenter only when the train leaves the viewport.
func _keep_train_in_view() -> void:
	if inspecting_map or size.x <= 0.0 or size.y <= 0.0 or journey == null:
		return
	var lag := maxf(0.0, journey.distance_travelled() - _visual_arc)
	var bounds: Rect2 = train_renderer.screen_bounds(self, journey, consist, lag)
	var viewport := Rect2(Vector2.ZERO, size)
	# Source: FIDELITE.md, constant visible size during travel. A train larger
	# than the viewport must be clipped, never shrunk; frame its nose instead.
	if bounds.size.x > size.x or bounds.size.y > size.y:
		var nose := _visual_position + Vector2(0.5, 0.5)
		if not viewport.has_point(_world_to_screen(nose)):
			camera_world = nose
			offset = Vector2.ZERO
		return
	if viewport.encloses(bounds):
		return
	_center_camera(_visual_position)
	bounds = train_renderer.screen_bounds(self, journey, consist, lag)
	offset += size * 0.5 - bounds.get_center()


func _snap_visual_position(position: Vector2) -> void:
	_visual_arc = journey.distance_travelled() if journey != null else 0.0
	_arc_from = _visual_arc
	_arc_to = _visual_arc
	_visual_from = position
	_visual_to = position
	_visual_position = position
	_visual_elapsed = 0.0
	_visual_initialized = true
	_interpolating = false


func _current_journey_position() -> Vector2:
	if journey == null:
		return Vector2(discovery.current_position)
	return Vector2(journey.fractional_position())


func _cycle_duration() -> float:
	if session == null:
		return 0.0
	return float(session.seconds_per_cycle)


func _can_animate() -> bool:
	return is_visible_in_tree() and session != null and not session.paused and not session.engine.event_pending


func _position_camera(position: Vector2) -> void:
	var nose_world := position + Vector2(0.5, 0.5)
	var desired_offset := (size * TRAIN_NOSE_SCREEN - size * 0.5) / _effective_zoom()
	camera_world = nose_world - _unproject(desired_offset)
	offset = Vector2.ZERO
	zoom = _effective_zoom()


func _world_to_screen(position: Vector2) -> Vector2:
	return size * 0.5 + offset + (_project(position) - _project(camera_world)) * _effective_zoom()


func _project(position: Vector2) -> Vector2:
	return WORLD_EAST * position.x + WORLD_SOUTH * position.y


func _screen_to_world(point: Vector2) -> Vector2:
	var projected := ((point - size * 0.5 - offset) / _effective_zoom()) + _project(camera_world)
	return _unproject(projected)


func _unproject(projected: Vector2) -> Vector2:
	return projected / CELL_PIXELS


func _cell_polygon(x: int, y: int) -> PackedVector2Array:
	return PackedVector2Array([
		_world_to_screen(Vector2(x, y)), _world_to_screen(Vector2(x + 1, y)),
		_world_to_screen(Vector2(x + 1, y + 1)), _world_to_screen(Vector2(x, y + 1)),
	])


func _visible_world_bounds() -> Rect2i:
	var corners := [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]
	var first := _screen_to_world(corners[0])
	var minimum := first
	var maximum := first
	for corner in corners.slice(1):
		var position := _screen_to_world(corner)
		minimum = minimum.min(position)
		maximum = maximum.max(position)
	var origin := Vector2i(floori(minimum.x) - 1, floori(minimum.y) - 1)
	var end := Vector2i(ceili(maximum.x) + 1, ceili(maximum.y) + 1)
	return Rect2i(origin, end - origin)


func _effective_zoom() -> float:
	return clampf(zoom, TRAVEL_MIN_ZOOM, TRAVEL_MAX_ZOOM)


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _finish_pointer_gesture(point: Vector2) -> void:
	if _left_held and not _dragging and point.distance_to(_press_origin) < DRAG_THRESHOLD and _city_at(point) < 0:
		var world := _screen_to_world(point)
		if toggle_switch_at(Vector2i(floori(world.x), floori(world.y))):
			_left_held = false
			return
	super._finish_pointer_gesture(point)


# CARTE 0x123f..0x1270: clicking a switch on the map flips its parity.
func toggle_switch_at(cell: Vector2i) -> bool:
	if network == null or not _cell_is_visible(cell.x, cell.y) or not network.toggle_switch(cell):
		return false
	switch_toggled.emit(cell)
	queue_redraw()
	return true
