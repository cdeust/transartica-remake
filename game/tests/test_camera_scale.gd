extends SceneTree

# Source: FIDELITE.md, owner forbids automatic zoom changes during travel.
const World = preload("res://scripts/travel_world.gd")
const Data = preload("res://scripts/world_data.gd")
const Journey = preload("res://scripts/train_journey.gd")
const Rails = preload("res://scripts/rail_network.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.low_processor_usage_mode = false
	var data = Data.new()
	if not data.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")):
		push_error("private map unavailable")
		quit(1)
		return
	var view = World.new()
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
	view.update_train()
	view.camera_world = Vector2.ZERO
	var bounds: Rect2 = view.train_renderer.screen_bounds(view, view.journey, view.consist, 0.0)
	_check(bounds.size.x > view.size.x or bounds.size.y > view.size.y, "fixture exceeds viewport")
	view._keep_train_in_view()
	_check(view.zoom == 1.0, "edge recenter preserves chosen zoom")
	var nose: Vector2 = view._world_to_screen(view._visual_position + Vector2(0.5, 0.5))
	_check(Rect2(Vector2.ZERO, view.size).has_point(nose), "oversized consist keeps locomotive visible")
	var camera: Vector2 = view.camera_world
	var offset: Vector2 = view.offset
	view._keep_train_in_view()
	_check(view.camera_world == camera and view.offset == offset, "oversized train does not recenter each frame")
	view.zoom_by(1.5, view.size * 0.5)
	var manual_zoom: float = view.zoom
	view._keep_train_in_view()
	_check(view.zoom == manual_zoom, "manual zoom survives travel framing")
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
		print("PASS: fixed zoom, oversized consist, stable camera, manual zoom")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
