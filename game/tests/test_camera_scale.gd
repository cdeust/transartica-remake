extends SceneTree

# Source: FIDELITE.md, owner forbids automatic zoom changes during travel.
const World = preload("res://scripts/travel_world.gd")
const Data = preload("res://scripts/world_data.gd")
const Journey = preload("res://scripts/train_journey.gd")
const Rails = preload("res://scripts/rail_network.gd")
var failures: Array[String] = []
var world_script = World

# Long synthetic route histories exercise all headings and a smooth rail bend;
# unlike the starting network segment, each fixture supports all six full poses.
class CompleteRoute:
	extends RefCounted
	var direction := Vector2.RIGHT
	var curved := false
	var travel := 0.0
	var heading := 6 # read by the travel-direction cue
	var reverse := false # read by the reverser snap in update_train

	func point_at(distance: float) -> Vector2:
		if curved:
			# Authored test radius: a gentle curve keeps the renderer chord search
			# monotonic across its per-wagon bracket while bending the whole train.
			return Vector2(40, 40) + Vector2(sin(distance / 3.0), 1.0 - cos(distance / 3.0)) * 3.0
		return Vector2(40, 40) + direction * distance

	func sample_behind(distance: float) -> Dictionary:
		return {"ok": true, "position": point_at(travel - distance), "heading": 6}

	func distance_travelled() -> float:
		return travel

	func fractional_position() -> Vector2:
		return point_at(travel)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.low_processor_usage_mode = false
	if "--baseline-camera" in OS.get_cmdline_user_args():
		var baseline := GDScript.new()
		baseline.source_code = FileAccess.get_file_as_string("res://../.cache/camera-baseline.gd")
		assert(baseline.reload() == OK,"committed camera baseline compiles")
		world_script = baseline
	var data = Data.new()
	if not data.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")):
		push_error("private map unavailable")
		quit(1)
		return
	var view = world_script.new()
	view.world_data = data
	view.network = Rails.new()
	view.network.load_bytes(data.map_bytes)
	view.journey = Journey.new()
	view.journey.network = view.network
	root.add_child(view)
	await process_frame
	# Deliberately small viewport: a real six-car consist cannot fit at zoom 1.
	root.size = Vector2i(320, 200)
	root.content_scale_size = root.size
	view.size = Vector2(320, 200)
	view.zoom = 1.0
	# Preserve prior east-axis chord while correcting the map orientation.
	_check(is_equal_approx(view.WORLD_EAST.length(), Vector2(180, 100).length()), "orientation change preserves vehicle pixel scale")
	_check(is_equal_approx(float(view._ground_material.get_shader_parameter("cell_pixels")), view.CELL_PIXELS), "ground uses the same square-axis pixel scale")
	view.update_train()
	view.camera_world = Vector2.ZERO
	var bounds: Rect2 = view.train_renderer.screen_bounds(view, view.journey, view.consist, 0.0)
	_check(bounds.size.x > view.size.x or bounds.size.y > view.size.y, "fixture exceeds viewport")
	view._keep_train_in_view()
	_check(view.zoom == 1.0, "edge recenter preserves chosen zoom")
	var nose: Vector2 = view._world_to_screen(view._visual_position + Vector2(0.5, 0.5))
	_check(Rect2(Vector2.ZERO, view.size).has_point(nose), "oversized consist keeps locomotive visible")
	var locomotive := {"vehicles":[view.consist.vehicles[0]]}
	var locomotive_bounds: Rect2 = view.train_renderer.screen_bounds(view,view.journey,locomotive,0.0)
	_check(Rect2(Vector2.ZERO,view.size).encloses(locomotive_bounds),"oversized consist keeps the entire locomotive visible")
	var camera: Vector2 = view.camera_world
	var offset: Vector2 = view.offset
	view._keep_train_in_view()
	_check(view.camera_world == camera and view.offset == offset, "oversized train does not recenter each frame")
	view.zoom_by(1.5, view.size * 0.5)
	var manual_zoom: float = view.zoom
	view._keep_train_in_view()
	_check(view.zoom == manual_zoom, "manual zoom survives travel framing")
	_test_complete_consist(view)
	_test_clipped_contact(view)
	if "--capture" in OS.get_cmdline_user_args():
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../tasks/validation/camera-scale-native.png"))
	view.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: fixed zoom, complete consist initial framing, stable movement and manual zoom")
	quit(0 if failures.is_empty() else 1)

func _test_complete_consist(view: Control) -> void:
	var route := CompleteRoute.new()
	view.journey = route
	var data_before: PackedInt32Array = view.network._tiles.duplicate()
	for viewport in [Vector2(320, 149), Vector2(1280, 596), Vector2(600, 800)]:
		view.size = viewport
		for heading in Rails.DELTAS:
			if heading == 5:
				continue
			route.direction = Vector2(Rails.DELTAS[heading]).normalized()
			route.curved = false
			route.travel = 0.0
			_check_complete_fit(view, route)
		route.curved = true
		_check_complete_fit(view, route)
	_check(view.network._tiles == data_before, "camera fitting never changes original network")


func _check_complete_fit(view: Control, route: CompleteRoute) -> void:
	view._visual_initialized = false
	view.update_train()
	view.fit_complete_consist()
	var fitted_zoom: float = view.zoom
	for distance in [0.0, 0.2, 1.0, 3.0, 7.0]:
		route.travel = distance
		view._snap_visual_position(route.fractional_position())
		view.update_train()
		var poses: Array = view.train_renderer.poses(view, route, view.consist, 0.0)
		_check(poses.size() == 6, "full-history fixture must draw all six vehicles")
		var bounds: Rect2 = view.train_renderer.screen_bounds(view, route, view.consist, 0.0)
		_check(Rect2(Vector2.ZERO, view.size).encloses(bounds), "complete train fits at every heading and curve")
		_check(view.zoom == fitted_zoom, "initially fitted zoom remains fixed throughout movement")

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _test_clipped_contact(view: Control) -> void:
	# Native terminal87,30 FWD: its contact was inside the top edge but the
	# rigid locomotive alpha extended outside. Dimensions come from its asset.
	var route := CompleteRoute.new()
	route.direction = Vector2.DOWN
	route.reverse = true
	route.heading = 8
	view.journey = route
	view.size = Vector2(320,200)
	view.zoom = 1.0
	view._snap_visual_position(route.fractional_position())
	view.camera_world = route.fractional_position()+Vector2(0.5,0.5)
	view.offset = Vector2(0.0,1.0-view.size.y*0.5) # Contact one pixel inside top.
	var locomotive := {"vehicles":[view.consist.vehicles[0]]}
	var viewport := Rect2(Vector2.ZERO,view.size)
	var bounds: Rect2 = view.train_renderer.screen_bounds(view,route,locomotive,0.0)
	_check(viewport.has_point(view._world_to_screen(route.fractional_position()+Vector2(0.5,0.5))) and not viewport.encloses(bounds),"fixture keeps contact visible while clipping locomotive alpha")
	view._keep_train_in_view()
	_check(viewport.encloses(view.train_renderer.screen_bounds(view,route,locomotive,0.0)),"camera frames locomotive alpha before its contact leaves the view")
	_check(view.zoom == 1.0,"clipped locomotive correction preserves fixed scale")
