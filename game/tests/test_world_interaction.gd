extends SceneTree

const WorldData = preload("res://scripts/world_data.gd")
const WorldView = preload("res://scripts/world_view.gd")
const RailGlyphs = preload("res://scripts/rail_glyphs.gd")

var picked_indices: Array[int] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var data = WorldData.new()
	var project_root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	_check(data.load_from_project(project_root), "reference map and city data load", failures)
	if failures.is_empty():
		await _test_click_and_drag(data, failures)
		_test_zoom_bounds(failures)
		_test_glyph_ports(failures)
		await _test_render_preserves_source(data, failures)
	if failures.is_empty():
		print("PASS: map interaction, zoom bounds, evidenced rail glyph ports, and source-data preservation")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_click_and_drag(data, failures: Array[String]) -> void:
	var view = WorldView.new()
	view.size = Vector2(1200, 700)
	view.world_data = data
	view.discovery.visit_cell(Vector2i(data.cities[0].x, data.cities[0].y))
	view.fit_world()
	root.add_child(view)
	view.city_picked.connect(_on_city_picked)
	await process_frame
	var city_point: Vector2 = view._city_screen_point(data.cities[0])
	_check(view._city_at(city_point + Vector2(9, 0)) == 0, "city hit target tolerates nine screen pixels", failures)
	view._gui_input(_button(MOUSE_BUTTON_LEFT, true, city_point))
	view._gui_input(_button(MOUSE_BUTTON_LEFT, false, city_point))
	_check(picked_indices == [0] and view.selected_city == 0, "click selects and emits the city index", failures)
	var before_pan: Vector2 = view.offset
	var city_again: Vector2 = view._city_screen_point(data.cities[0])
	view._gui_input(_button(MOUSE_BUTTON_LEFT, true, city_again))
	view._gui_input(_motion(city_again + Vector2(30, 16)))
	view._gui_input(_button(MOUSE_BUTTON_LEFT, false, city_again + Vector2(30, 16)))
	_check(view.offset != before_pan, "drag pans map", failures)
	_check(picked_indices == [0], "drag does not select or emit a city", failures)
	_check(view.diagnostic == false, "diagnostic layer stays inactive by default", failures)
	view.queue_free()
	await process_frame


func _test_zoom_bounds(failures: Array[String]) -> void:
	var view = WorldView.new()
	view.size = Vector2(1, 1)
	view.fit_world()
	_check(is_equal_approx(view.zoom, WorldView.MIN_ZOOM), "fit respects minimum zoom", failures)
	view.zoom_by(1000.0, Vector2(100, 100))
	_check(is_equal_approx(view.zoom, WorldView.MAX_ZOOM), "wheel zoom respects maximum", failures)
	view.zoom_by(0.0)
	_check(is_equal_approx(view.zoom, WorldView.MAX_ZOOM), "invalid zoom factor leaves view unchanged", failures)
	view.size = Vector2(100000, 100000)
	view.fit_world()
	_check(is_equal_approx(view.zoom, WorldView.MAX_ZOOM), "fit respects maximum zoom", failures)
	var label := view._clamp_label_box(Rect2(Vector2(-50, 20000), Vector2(100, 24)))
	_check(label.position.x >= 0.0 and label.position.y + label.size.y <= view.size.y, "label box stays within viewport", failures)
	view.free()


func _test_glyph_ports(failures: Array[String]) -> void:
	var expected := {
		2: [Vector2(-0.5, 0), Vector2(0.5, 0)], 3: [Vector2(0, -0.5), Vector2(0, 0.5)],
		4: [Vector2(0.5, -0.5), Vector2(-0.5, 0.5)], 5: [Vector2(-0.5, -0.5), Vector2(0.5, 0.5)],
		6: [Vector2(-0.5, 0), Vector2(0.5, 0.5)], 7: [Vector2(0.5, 0), Vector2(-0.5, 0.5)],
		8: [Vector2(0.5, 0), Vector2(-0.5, -0.5)], 9: [Vector2(-0.5, 0), Vector2(0.5, -0.5)],
		10: [Vector2(0, 0.5), Vector2(-0.5, -0.5)], 11: [Vector2(0, 0.5), Vector2(0.5, -0.5)],
		12: [Vector2(0, -0.5), Vector2(-0.5, 0.5)], 13: [Vector2(0, -0.5), Vector2(0.5, 0.5)],
		14: [Vector2(0, -0.5), Vector2(0.5, 0), Vector2(0, 0.5), Vector2(-0.5, 0)],
		15: [Vector2(0, -0.5), Vector2(0.5, 0), Vector2(0, 0.5), Vector2(-0.5, 0)],
		16: [Vector2(0, -0.5), Vector2(0.5, 0), Vector2(0, 0.5), Vector2(-0.5, 0)],
		17: [Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5), Vector2(-0.5, -0.5)],
		18: [Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(0.5, -0.5)],
		20: [Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(-0.5, -0.5)],
		22: [Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(0.5, 0.5)],
		24: [Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(-0.5, 0.5)],
		26: [Vector2(0, -0.5), Vector2(0, 0.5), Vector2(0.5, 0.5)],
		28: [Vector2(0, -0.5), Vector2(0, 0.5), Vector2(-0.5, 0.5)],
		30: [Vector2(0, -0.5), Vector2(0, 0.5), Vector2(0.5, -0.5)],
		32: [Vector2(0, -0.5), Vector2(0, 0.5), Vector2(-0.5, -0.5)],
	}
	for code in expected:
		var variants := [int(code)]
		if code >= 18 and code <= 33:
			variants.append(int(code) + 1)
		if code == 2:
			variants.append_array([39, 50, 54, 56, 58])
		if code == 3:
			variants.append_array([38, 52, 53])
		if code == 17:
			variants.append(49)
		if code == 4:
			variants.append(41)
		if code == 5:
			variants.append(40)
		for variant in variants:
			_check(RailGlyphs.ports_for_code(variant) == expected[code], "evidenced ports for code %d" % variant, failures)
	for code in [1, 34, 70, 77, 255]:
		_check(RailGlyphs.ports_for_code(code).is_empty(), "unknown code %d has no inferred ports" % code, failures)
	for code in range(71, 77):
		_check(RailGlyphs._is_city_code(code), "city tile code %d stays with city markers" % code, failures)


func _test_render_preserves_source(data, failures: Array[String]) -> void:
	var original_map: PackedByteArray = data.map_bytes.duplicate()
	var original_cities: Array[Dictionary] = data.cities.duplicate(true)
	var view = WorldView.new()
	view.size = Vector2(1000, 620)
	view.world_data = data
	view.discovery.visit_cell(Vector2i(data.cities[0].x, data.cities[0].y))
	view.fit_world()
	root.add_child(view)
	await process_frame
	_check(data.map_bytes == original_map, "drawing rail glyphs leaves original map bytes unchanged", failures)
	_check(data.cities == original_cities, "drawing rail glyphs leaves decoded coordinates unchanged", failures)
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(data.map_bytes)
	_check(hasher.finish().hex_encode() == "8e1067619b254d57717348fefedc1b5013eb1d7ba23200a815e36f9b856d811a", "render preserves original map SHA-256", failures)
	view.queue_free()
	await process_frame


func _button(button: MouseButton, pressed: bool, point: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = point
	return event


func _motion(point: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = point
	return event


func _on_city_picked(index: int) -> void:
	picked_indices.append(index)


func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
