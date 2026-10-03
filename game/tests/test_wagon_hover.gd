extends SceneTree
# requires-native-renderer
# MIT. Native highlight/input contract: tasks/wagon-masks-20261002.md.
const Boudoir = preload("res://scripts/boudoir_screen.gd")
const Quarters = preload("res://scripts/general_quarters.gd")
# source: owner acceptance and measured PNG identities, 3 October 2026.
const ACCEPTED_MANIFEST := "res://../tasks/validation/wagon-cutouts-accepted-20261003.json"
var failures: Array[String] = []
var actions: Array[int] = []
var captures := false
var raster_candidates := false
var legacy_svg := false
var pointer := Vector2.ZERO


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	# Keep OS pointer motion from racing the explicitly dispatched GUI events.
	root.gui_disable_input = true
	captures = "--capture" in OS.get_cmdline_user_args()
	raster_candidates = "--raster-candidates" in OS.get_cmdline_user_args()
	legacy_svg = "--legacy-svg" in OS.get_cmdline_user_args()
	_check(not (raster_candidates and legacy_svg), "candidate and legacy modes are mutually exclusive")
	if raster_candidates or not str(_paths(Boudoir.MASKS)[10]).ends_with(".png"):
		_check_occlusions()
	else:
		_check_accepted_cutouts()
	for kind in ["boudoir", "quarters"]:
		var view = Boudoir.new() if kind == "boudoir" else Quarters.new()
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(view)
		view.action_requested.connect(func(code: int): actions.append(code))
		await process_frame
		view.show()
		if raster_candidates or legacy_svg:
			view.hover_layer.configure(_paths(view.MASKS))
		for dimensions in [Vector2i(1440, 900), Vector2i(1000, 800)]:
			await _check_size(view, kind, dimensions)
		if kind == "boudoir":
			await _move(view, view.REGIONS[11].get_center())
			view.inventory.show()
			var motion := InputEventMouseMotion.new()
			motion.position = Vector2.ZERO
			view._gui_input(motion)
			_check(not view.hover_layer.visible, "inventory blocks highlight")
		view.queue_free()
		await process_frame
	if failures.is_empty():
		var contract := "strict candidate occlusions" if raster_candidates else "legacy SVG occlusions" if legacy_svg else "accepted PNG identity/registration"
		print("PASS: %s; eight native highlights, GUI handlers, resize, clear and modal checks" % contract)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_size(view: Control, kind: String, dimensions: Vector2i) -> void:
	root.size = dimensions
	await process_frame
	await process_frame
	await _move(view, Vector2(0.6, 0.1))
	var baseline := await _image()
	for code: int in view.REGIONS:
		await _move(view, view.REGIONS[code].get_center())
		_check(view.hover_layer.visible and view.hover_layer.hovered_code == code, "%s hover %d" % [kind, code])
		_check(view.hover_layer.material.shader.resource_path == "res://shaders/object_hover.gdshader", "same engine-room shader")
		_check(view.hover_layer.material.get_shader_parameter("coverage_from_alpha") == str(_paths(view.MASKS)[code]).ends_with(".png"), "registered layer chooses its coverage channel")
		var highlighted := await _image()
		_check(highlighted.get_data() != baseline.get_data(), "native golden pixels for %s/%d" % [kind, code])
		if captures and dimensions == Vector2i(1440, 900):
			var path := "res://../tasks/validation/wagon-hover-%s-%d-20261002.png" % [kind, code]
			_check(highlighted.save_png(ProjectSettings.globalize_path(path)) == OK, "capture " + path)
		await _click(view)
		_check(not actions.is_empty() and actions.back() == code, "existing click action %s/%d" % [kind, code])
		_check(not view.hover_layer.visible, "click clears highlight")
		await _move(view, Vector2(0.6, 0.1))
		_check(not view.hover_layer.visible, "empty scene clears highlight")
		_check((await _image()).get_data() == baseline.get_data(), "hover reset restores base pixels")
	await _move(view, view.REGIONS[11].get_center())
	view.hide()
	_check(not view.hover_layer.visible, "hide clears hover")
	view.show()
	await process_frame


func _move(view: Control, normalized: Vector2) -> void:
	var bounds: Rect2 = view.canvas_rect()
	bounds.size.y *= 149.0 / 200.0
	var motion := InputEventMouseMotion.new()
	pointer = bounds.position + normalized * bounds.size
	motion.position = pointer
	view._gui_input(motion)


func _click(view: Control) -> void:
	var event := InputEventMouseButton.new()
	event.position = pointer
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	view._gui_input(event)
	event = event.duplicate()
	event.pressed = false
	view._gui_input(event)
	await process_frame


func _image() -> Image:
	await process_frame
	RenderingServer.force_draw(true)
	return root.get_texture().get_image()


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _check_occlusions() -> void:
	# source: former binary SVG contract, tasks/wagon-masks-20261002.md renewed review.
	# Candidates retain strict occlusions; accepted PNGs use identity/registration.
	# Their baseline does not claim the three missing exclusions are present.
	var officer := (load(_paths(Quarters.MASKS)[13]) as Texture2D).get_image()
	_check(_coverage(officer, Vector2i(1458, 822)) == 0.0, "window wood between officer arm and coat excluded")
	_check(_coverage(officer, Vector2i(1500, 810)) > 0.99, "officer coat retained beside the window gap")
	var stoup := (load(_paths(Quarters.MASKS)[10]) as Texture2D).get_image()
	_check(_coverage(stoup, Vector2i(73, 720)) == 0.0, "pipe occluding the stoup excluded")
	_check(_coverage(stoup, Vector2i(100, 820)) > 0.99, "stoup body retained beside pipe")
	var operator := (load(_paths(Quarters.MASKS)[11]) as Texture2D).get_image()
	_check(_coverage(operator, Vector2i(175, 772)) == 0.0, "floor beside operator toe excluded")
	_check(_coverage(operator, Vector2i(200, 770)) > 0.99, "operator boot retained beside floor")
	_check(_coverage(operator, Vector2i(256, 698)) > 0.99, "dark rear boot shaft retained beside narrow floor gap")
	var book := (load(_paths(Boudoir.MASKS)[13]) as Texture2D).get_image()
	_check(_coverage(book, Vector2i(1350, 634)) == 0.0, "wood above open page excluded")
	_check(_coverage(book, Vector2i(1430, 630)) > 0.99, "upper right page retained")
	var kolotov := (load(_paths(Boudoir.MASKS)[11]) as Texture2D).get_image()
	_check(_coverage(kolotov, Vector2i(422, 488)) > 0.99, "outer white sleeve retained")
	_check(_coverage(kolotov, Vector2i(364, 419)) == 0.0, "wood beside neck excluded")
	var map := (load(_paths(Quarters.MASKS)[12]) as Texture2D).get_image()
	_check(_coverage(map, Vector2i(1195, 575)) > 0.99, "right wooden map frame retained")


func _paths(original: Dictionary) -> Dictionary:
	var result := original.duplicate()
	if raster_candidates:
		for code in result:
			result[code] = str(result[code]).replace("/masks/", "/cutouts/").replace(".svg", ".png")
	elif legacy_svg:
		for code in result:
			result[code] = str(result[code]).replace("/cutouts/", "/masks/").replace(".png", ".svg")
	return result


func _coverage(image: Image, pixel: Vector2i) -> float:
	var color := image.get_pixelv(pixel)
	return color.a if str(_paths(Boudoir.MASKS)[10]).ends_with(".png") else color.r


func _check_accepted_cutouts() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(ACCEPTED_MANIFEST))
	_check(manifest is Dictionary and manifest.get("entries") is Array, "accepted cutout manifest is available")
	if not manifest is Dictionary or not manifest.get("entries") is Array:
		return
	var active: Array = Boudoir.MASKS.values() + Quarters.MASKS.values()
	var seen: Array = []
	for entry in manifest.entries:
		var path: String = entry.path
		_check(path in active and not path in seen, "manifest maps an active cutout exactly once: " + path)
		seen.append(path)
		_check(FileAccess.get_sha256(path) == entry.sha256, "registered PNG baseline unchanged: " + path)
		var image := (load(path) as Texture2D).get_image()
		var source := (load(entry.source_scene) as Texture2D).get_image()
		_check(FileAccess.get_sha256(entry.source_scene) == entry.source_scene_sha256, "registered accepted scene unchanged: " + path)
		_check(image.get_size() == Vector2i(entry.size[0], entry.size[1]), "accepted canvas dimensions: " + path)
		_check(image.get_size() == source.get_size(), "scene registration dimensions: " + path)
		for point in entry.exterior_pixels:
			_check(image.get_pixel(point[0], point[1]).a == 0.0, "known exterior stays transparent: " + path)
		for point in entry.measured_points:
			var pixel: Array = point.pixel
			_check(roundi(image.get_pixel(pixel[0], pixel[1]).a * 255.0) == int(point.alpha), "measured registered alpha: %s %s" % [path, pixel])
		if entry.exact_source_rgb:
			_check_source_registration(image, source, path)
	_check(seen.size() == active.size(), "all active accepted cutouts have baselines")


func _check_source_registration(image: Image, source: Image, path: String) -> void:
	# source: local table/revolver extraction copies source RGB unchanged;
	# tasks/validation/wagon-local-inspection-20261003.json.
	var registered := image.get_size() == source.get_size()
	if registered:
		for y in image.get_height():
			for x in image.get_width():
				var color := image.get_pixel(x, y)
				if color.a > 0.0:
					var original := source.get_pixel(x, y)
					if color.r != original.r or color.g != original.g or color.b != original.b:
						registered = false
	_check(registered, "locally extracted RGB keeps exact scene registration: " + path)
