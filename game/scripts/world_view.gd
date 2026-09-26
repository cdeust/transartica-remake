extends Control
class_name SurveyWorldView

const WorldDataScript = preload("res://scripts/world_data.gd")
const RailGlyphsScript = preload("res://scripts/rail_glyphs.gd")
const MapDiscoveryScript = preload("res://scripts/map_discovery.gd")

const TILE_PIXELS := 5.0 # source: tasks/execution-contract.md; preview layout choice
const MIN_ZOOM := 0.4 # source: tasks/execution-contract.md; overview layout choice
const MAX_ZOOM := 32.0 # source: tasks/execution-contract.md; city inspection layout choice
const WHEEL_ZOOM_STEP := 1.2 # source: tasks/execution-contract.md; wheel input choice
const PAN_SPEED_PIXELS_PER_SECOND := 250.0 # source: tasks/execution-contract.md; keyboard control choice
# Original cold-palette design choices: preserve code distinction without implying terrain classes.
const BYTE_CODE_MAX := 255.0 # source: CARTE.FIC byte format, FORMAT-CARTE.md
const MAP_HUE_START := 0.47 # source: original pixel palette design choice
const MAP_HUE_SPAN := 0.14 # source: original pixel palette design choice
const MAP_SATURATION := 0.48 # source: original pixel palette design choice
const MAP_VALUE_START := 0.22 # source: original pixel palette design choice
const MAP_VALUE_SPAN := 0.20 # source: original pixel palette design choice
const CITY_HIT_RADIUS := 10.0 # source: authored screen-space interaction target.
const DRAG_THRESHOLD := 4.0 # source: authored gesture separation for click vs pan.
const PAPER := Color("#eee9d7") # source: tasks/evidence/chart-design.md; authored ice-paper palette.
const INK := Color("#173641") # source: tasks/evidence/chart-design.md; authored petroleum ink.
const GRID := Color("#c9d1c7") # source: authored low-contrast coordinate grid.
const BRASS := Color("#ad8b52") # source: tasks/visual-design.md; authored frame accent.
const UNKNOWN := Color("#d6dfdc") # source: authored fog treatment for undiscovered cells.

var journey
var following_train := true
var world_data
var discovery = MapDiscoveryScript.new()
var discovery_enabled := true # source: user-authorized fog-of-war preview; not an original-game rule.
var zoom := 1.0
var offset := Vector2.ZERO
var selected_city := -1
var diagnostic := false
var _press_origin := Vector2.ZERO
var _last_pointer := Vector2.ZERO
var _left_held := false
var _dragging := false

signal city_picked(index: int)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func fit_world() -> void:
	var extent := Vector2(WorldDataScript.MAP_WIDTH, WorldDataScript.MAP_HEIGHT) * TILE_PIXELS
	zoom = clampf(minf(size.x / extent.x, size.y / extent.y) * 0.94, MIN_ZOOM, MAX_ZOOM)
	offset = (size - extent * zoom) * 0.5
	queue_redraw()


func fit_discovered() -> void:
	var bounds: Rect2i = discovery.discovered_bounds()
	if bounds.size == Vector2i.ZERO:
		return
	var origin := Vector2(bounds.position) * TILE_PIXELS
	var extent := Vector2(bounds.size) * TILE_PIXELS
	zoom = clampf(minf(size.x / extent.x, size.y / extent.y) * 0.94, MIN_ZOOM, MAX_ZOOM)
	offset = (size - extent * zoom) * 0.5 - origin * zoom
	queue_redraw()


func visit_cell(position: Vector2i) -> bool:
	var changed: bool = discovery.current_position != position
	if not discovery.visit_cell(position):
		return false
	if changed:
		if selected_city >= 0 and not _city_is_visible(world_data.cities[selected_city]):
			selected_city = -1
		queue_redraw()
	return true


func pan_by(delta: Vector2) -> void:
	following_train = false
	offset += delta
	queue_redraw()


func zoom_by(factor: float, anchor: Vector2 = Vector2.ZERO) -> void: # source: tasks/execution-contract.md, preview control choice
	# source: authored API guard; keeps cursor transforms finite and positive.
	if not is_finite(factor) or factor <= 0.0: # source: reject invalid zoom requests before division.
		return
	var next_zoom := clampf(zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(next_zoom, zoom):
		return
	offset = anchor - (anchor - offset) * next_zoom / zoom
	zoom = next_zoom
	queue_redraw()


func focus_city(index: int) -> void:
	if world_data == null or index < 0 or index >= world_data.cities.size():
		return
	var city: Dictionary = world_data.cities[index]
	if not _city_is_visible(city):
		return
	selected_city = index
	var tile := (Vector2(float(city.x), float(city.y)) + Vector2(0.5, 0.5)) * TILE_PIXELS
	offset = size * 0.5 - tile * zoom
	queue_redraw()


func _draw() -> void:
	if world_data == null or world_data.map_bytes.is_empty():
		return
	_draw_chart()
	if diagnostic:
		_draw_map()
	_draw_unknown_cells()
	_draw_frame()
	_draw_cities()
	_draw_train()


func _draw_chart() -> void:
	# source: tasks/evidence/chart-design.md; authored cartographic presentation.
	draw_rect(Rect2(Vector2.ZERO, size), UNKNOWN)
	_draw_coordinate_grid()
	_draw_network()


func _draw_coordinate_grid() -> void:
	var bounds: Rect2i = discovery.discovered_bounds()
	if bounds.size == Vector2i.ZERO:
		return
	var left := offset.x + bounds.position.x * TILE_PIXELS * zoom
	var top := offset.y + bounds.position.y * TILE_PIXELS * zoom
	var right := left + bounds.size.x * TILE_PIXELS * zoom
	var bottom := top + bounds.size.y * TILE_PIXELS * zoom
	for x in range(bounds.position.x, bounds.end.x + 1, 10):
		var px := offset.x + x * TILE_PIXELS * zoom
		draw_line(Vector2(px, top), Vector2(px, bottom), GRID, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(px + 3, top + 13), str(x), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)
	for x in range(bounds.position.x, bounds.end.x + 1, 5):
		if x % 10 == 0:
			continue
		var px := offset.x + x * TILE_PIXELS * zoom
		draw_line(Vector2(px, top), Vector2(px, bottom), GRID.darkened(0.12), 0.6)
	for y in range(bounds.position.y, bounds.end.y + 1, 10):
		var py := offset.y + y * TILE_PIXELS * zoom
		draw_line(Vector2(left, py), Vector2(right, py), GRID, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(left + 3, py + 13), str(y), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)
	for y in range(bounds.position.y, bounds.end.y + 1, 5):
		if y % 10 == 0:
			continue
		var py := offset.y + y * TILE_PIXELS * zoom
		draw_line(Vector2(left, py), Vector2(right, py), GRID.darkened(0.12), 0.6)


func _draw_network() -> void:
	# source: tasks/evidence/rail-glyphs.md; glyph ports are not a route graph.
	var tile_size := TILE_PIXELS * zoom
	for x in WorldDataScript.MAP_WIDTH:
		for y in WorldDataScript.MAP_HEIGHT:
			if not _cell_is_visible(x, y):
				continue
			var code: int = world_data.map_code(x, y)
			if code == 0:
				continue
			var origin := offset + Vector2(x, y) * tile_size
			RailGlyphsScript.draw_tile(self, code, origin, tile_size)


func _draw_frame() -> void:
	var bounds: Rect2i = discovery.discovered_bounds()
	if bounds.size == Vector2i.ZERO:
		return
	var origin := offset + Vector2(bounds.position) * TILE_PIXELS * zoom
	var extent := Vector2(bounds.size) * TILE_PIXELS * zoom
	draw_rect(Rect2(origin, extent), INK, false, 1.0)
	var corner := 12.0 # source: tasks/visual-design.md, authored atlas corner marks.
	for point in [origin, origin + Vector2(extent.x, 0), origin + extent, origin + Vector2(0, extent.y)]:
		var horizontal := corner if point.x == origin.x else -corner
		var vertical := corner if point.y == origin.y else -corner
		draw_line(point, point + Vector2(horizontal, 0), BRASS, 2.0)
		draw_line(point, point + Vector2(0, vertical), BRASS, 2.0)


func _draw_map() -> void:
	var tile_size := TILE_PIXELS * zoom
	for x in WorldDataScript.MAP_WIDTH:
		for y in WorldDataScript.MAP_HEIGHT:
			if not _cell_is_visible(x, y):
				continue
			var code = world_data.map_code(x, y)
			var rect := Rect2(offset + Vector2(x, y) * tile_size, Vector2(tile_size + 0.3, tile_size + 0.3))
			draw_rect(rect, _abstract_color(code))


func _draw_unknown_cells() -> void:
	var tile_size := TILE_PIXELS * zoom
	for x in WorldDataScript.MAP_WIDTH:
		for y in WorldDataScript.MAP_HEIGHT:
			if _cell_is_visible(x, y):
				continue
			var rect := Rect2(offset + Vector2(x, y) * tile_size, Vector2(tile_size + 0.4, tile_size + 0.4))
			draw_rect(rect, UNKNOWN)


func _draw_cities() -> void:
	var label_boxes: Array[Rect2] = []
	for index in world_data.cities.size():
		var city: Dictionary = world_data.cities[index]
		if not _city_is_visible(city):
			continue
		var point := offset + Vector2(float(city.x) + 0.5, float(city.y) + 0.5) * TILE_PIXELS * zoom
		_draw_town_sprite(point, index == selected_city)
		if index != selected_city and not diagnostic:
			_draw_city_label(point, String(city.name), label_boxes)
	if selected_city >= 0 and selected_city < world_data.cities.size() and _city_is_visible(world_data.cities[selected_city]):
		var selected: Dictionary = world_data.cities[selected_city]
		var selected_point := _city_screen_point(selected)
		_draw_selected_city(selected_point, String(selected.name))


func _city_screen_point(city: Dictionary) -> Vector2:
	return offset + Vector2(float(city.x) + 0.5, float(city.y) + 0.5) * TILE_PIXELS * zoom


func _city_is_visible(city: Dictionary) -> bool:
	return _cell_is_visible(int(city.x), int(city.y))


func _cell_is_visible(x: int, y: int) -> bool:
	return not discovery_enabled or discovery.is_discovered(x, y)


func _draw_train() -> void:
	var position := Vector2(discovery.current_position) if journey == null else Vector2(journey.fractional_position())
	var center := offset + (Vector2(position) + Vector2(0.5, 0.5)) * TILE_PIXELS * zoom
	# Authored map symbol: a directional locomotive with three trailing wagons.
	var unit := clampf(TILE_PIXELS * zoom * 0.12, 3.0, 10.0)
	for wagon in range(1, 4):
		var back := center - Vector2(unit * (2.7 * wagon), 0)
		draw_rect(Rect2(back - Vector2(unit, unit * 0.6), Vector2(unit * 2, unit * 1.2)), INK)
		draw_rect(Rect2(back - Vector2(unit * 0.8, unit * 0.4), Vector2(unit * 1.6, unit * 0.8)), BRASS)
	draw_rect(Rect2(center - Vector2(unit, unit * 0.7), Vector2(unit * 2, unit * 1.4)), INK)
	draw_colored_polygon(PackedVector2Array([center + Vector2(unit * 2, 0), center + Vector2(unit, -unit * 0.7), center + Vector2(unit, unit * 0.7)]), INK)
	draw_circle(center + Vector2(unit * 0.8, 0), unit * 0.35, BRASS)


func _draw_town_sprite(point: Vector2, selected: bool) -> void:
	var base := Color("#fffaf0") if selected else PAPER
	var mark := Color("#a67742") if selected else INK
	draw_rect(Rect2(point + Vector2(-4, 0), Vector2(8, 4)), base)
	draw_line(point + Vector2(-5, 0), point + Vector2(0, -4), mark, 1.5)
	draw_line(point + Vector2(0, -4), point + Vector2(5, 0), mark, 1.5)
	draw_rect(Rect2(point + Vector2(-3, 1), Vector2(6, 3)), mark)


func _draw_city_label(point: Vector2, label: String, occupied: Array[Rect2]) -> void:
	var font := ThemeDB.fallback_font
	var extent := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	var box := _clamp_label_box(Rect2(point + Vector2(8, -8), extent + Vector2(5, 4)))
	for prior in occupied:
		if box.intersects(prior):
			return
	occupied.append(box)
	draw_rect(box, PAPER)
	draw_string(font, box.position + Vector2(3, extent.y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)


func _draw_selected_city(point: Vector2, label: String) -> void:
	var text_size := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	var box := _clamp_label_box(Rect2(point + Vector2(10, -11), text_size + Vector2(12, 5)))
	draw_rect(box, Color("#fffaf0"))
	draw_rect(box, BRASS, false, 1.0)
	draw_rect(Rect2(point - Vector2(6, 6), Vector2(13, 13)), BRASS, false, 1.0)
	draw_string(ThemeDB.fallback_font, box.position + Vector2(6, text_size.y + 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)


func _clamp_label_box(box: Rect2) -> Rect2:
	var maximum := Vector2(maxf(0.0, size.x - box.size.x), maxf(0.0, size.y - box.size.y))
	box.position = box.position.clamp(Vector2.ZERO, maximum)
	return box


func _abstract_color(code: int) -> Color:
	# source: tasks/execution-contract.md; design choice, opaque map code diagnostics only
	var code_fraction := float(code) / BYTE_CODE_MAX
	var hue := MAP_HUE_START + code_fraction * MAP_HUE_SPAN
	var saturation := MAP_SATURATION
	var value := MAP_VALUE_START + code_fraction * MAP_VALUE_SPAN
	return Color.from_hsv(hue, saturation, value)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _left_held:
		_handle_pointer_motion(event.position)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		zoom_by(WHEEL_ZOOM_STEP, event.position)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		zoom_by(1.0 / WHEEL_ZOOM_STEP, event.position)
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_pointer_gesture(event.position)
		else:
			_finish_pointer_gesture(event.position)


func _begin_pointer_gesture(point: Vector2) -> void:
	_press_origin = point
	_last_pointer = point
	_left_held = true
	_dragging = false


func _handle_pointer_motion(point: Vector2) -> void:
	if not _dragging and point.distance_to(_press_origin) >= DRAG_THRESHOLD:
		_dragging = true
	if _dragging:
		pan_by(point - _last_pointer)
	_last_pointer = point


func _finish_pointer_gesture(point: Vector2) -> void:
	if not _left_held:
		return
	if not _dragging and point.distance_to(_press_origin) < DRAG_THRESHOLD:
		var city_index := _city_at(point)
		if city_index >= 0:
			selected_city = city_index
			city_picked.emit(city_index)
			queue_redraw()
	_left_held = false
	_dragging = false


func _city_at(point: Vector2) -> int:
	if world_data == null:
		return -1
	var nearest := -1
	var nearest_distance := CITY_HIT_RADIUS
	for index in world_data.cities.size():
		if not _city_is_visible(world_data.cities[index]):
			continue
		var candidate := _city_screen_point(world_data.cities[index])
		var distance := point.distance_to(candidate)
		if distance <= nearest_distance:
			nearest = index
			nearest_distance = distance
	return nearest


func follow_train() -> void:
	following_train = true
	update_train()


func update_train() -> void:
	if following_train and journey != null:
		offset = size * 0.5 - (Vector2(journey.fractional_position()) + Vector2.ONE * 0.5) * TILE_PIXELS * zoom
	queue_redraw()
