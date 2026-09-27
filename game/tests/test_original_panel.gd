extends SceneTree

const PanelScript = preload("res://scripts/original_panel.gd")
var failures: Array[String] = []
var received: Array[int] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var panel := PanelScript.new()
	root.add_child(panel)
	panel.requested.connect(func(code: int) -> void: received.append(code))
	# source: exact hit boxes in tasks/evidence/panel-layout.md. Test centers are
	# inside those independently documented bounds, not read from implementation.
	var points := {2: Vector2(24, 180), 6: Vector2(96, 168), 8: Vector2(130, 169),
		7: Vector2(96, 186), 9: Vector2(132, 187)}
	for viewport_size in [Vector2(320, 200), Vector2(1280, 800), Vector2(1600, 900), Vector2(600, 1000)]:
		panel.size = viewport_size
		await process_frame
		var frame: Rect2 = panel.frame_rect()
		_check(is_equal_approx(frame.size.x / frame.size.y, 1.6), "Original frame ratio changed")
		_check(frame.position.x >= 0 and frame.position.y >= 0, "Frame extends outside viewport")
		_test_readouts(panel)
		panel.map_context = false
		for code in points:
			_click(panel, points[code], code)
		_click(panel, Vector2(177, 169), 1)
		_click(panel, Vector2(210, 169), 0)
		_click(panel, Vector2(177, 189), 0)
		_click(panel, Vector2(210, 189), 0)
		panel.map_context = true
		_click(panel, Vector2(177, 169), 4)
		_click(panel, Vector2(210, 169), 1)
		_click(panel, Vector2(177, 189), 3)
		_click(panel, Vector2(210, 189), 5)
		var scene_point := _screen(panel, Vector2(100, 100))
		_check(not panel._has_point(scene_point), "HUD intercepts scene input")
		_check(panel.hotspot_at(scene_point) == 0, "Scene has an invented command")
		var border := _screen(panel, Vector2(80, 161))
		_check(panel.hotspot_at(border) == 6, "Inclusive start pixel lost on resize")
		_check(panel.hotspot_at(_screen(panel, Vector2(113, 168))) == 0, "Engine hit box exceeds source end")
	panel.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: original ECS panel command coordinates, contextual input, fitted resizing and readout containment")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_readouts(panel: Control) -> void:
	# Independent sampled black interiors exclude rounded frame/rivets. The source
	# rightmost slice is 464x389 displayed in logical90x51 at (230,149).
	var samples := [Rect2(1840, 298, 120, 55), Rect2(1840, 396, 120, 55), Rect2(1840, 492, 120, 57)]
	# EngineState restore accepts fuel through32767; test initial amounts and max.
	for value in ["0", "500", "2000", "32767"]:
		for index in range(samples.size()):
			var sample: Rect2 = samples[index]
			var logical := Rect2(Vector2(230, 149) + (sample.position - Vector2(1550, 190)) * Vector2(90.0 / 464, 51.0 / 389), sample.size * Vector2(90.0 / 464, 51.0 / 389))
			var safe_window: Rect2 = panel.screen_rect(logical).grow(-1.0)
			var layout: Dictionary = panel.readout_layout(value, index)
			_check(not layout.is_empty(), "Readout disappeared at %s index%d value%s" % [panel.size, index, value])
			if layout.is_empty():
				continue
			var font := ThemeDB.fallback_font
			var glyph_top: Vector2 = layout.baseline - Vector2(0, font.get_ascent(layout.font_size))
			var glyph_size := Vector2(font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, layout.font_size).x, font.get_ascent(layout.font_size) + font.get_descent(layout.font_size))
			var shadow_bounds := Rect2(glyph_top, glyph_size + Vector2.ONE)
			_check(safe_window.encloses(shadow_bounds), "Readout glyph/shadow exceeds measured inner frame: %s" % value)


func _screen(panel: Control, logical: Vector2) -> Vector2:
	return panel.screen_rect(Rect2(logical, Vector2.ONE)).position


func _click(panel: Control, logical: Vector2, expected: int) -> void:
	var point := _screen(panel, logical)
	_check(panel.hotspot_at(point) == expected, "Wrong hotspot at %s: expected %d" % [logical, expected])
	received.clear()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = point
	panel._gui_input(click)
	_check(received == ([expected] if expected != 0 else []), "Mouse click emitted wrong command at %s" % logical)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
