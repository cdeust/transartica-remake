extends SceneTree

# Native render evidence: actual map positions, unchanged network and camera.
const Travel = preload("res://scripts/travel_world.gd")
const Data = preload("res://scripts/world_data.gd")
const Network = preload("res://scripts/rail_network.gd")
var failures: Array[String] = []

func _initialize() -> void:
	OS.low_processor_usage_mode = false
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var data = Data.new()
	if not data.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")):
		push_error("Source world data missing")
		quit(1)
		return
	var view = Travel.new()
	view.size = Vector2(1280,720)
	view.world_data = data
	view.journey = preload("res://scripts/train_journey.gd").new()
	view.wagons = preload("res://scripts/train_wagons.gd").new()
	view.network = Network.new()
	view.network.load_bytes(data.map_bytes)
	view.journey.network = view.network
	view.session = preload("res://scripts/engine_session.gd").new(preload("res://scripts/engine_state.gd").new(),1.0)
	root.add_child(view)
	await process_frame
	var before: Dictionary = view.network.snapshot()
	view.fit_complete_consist()
	await _capture("start")
	view.following_train = false
	view.zoom = 0.65
	for scene in [{"name":"mountains", "cell":Vector2(8,8)}, {"name":"lake", "cell":Vector2(54,48)}, {"name":"forest", "cell":Vector2(80,11)}, {"name":"city", "cell":Vector2(63,42)}]:
		view.camera_world = scene.cell
		view.offset = Vector2.ZERO
		view.queue_redraw()
		await _capture(scene.name)
	if view.terrain.textures.size() != 79:
		failures.append("All79 original scenery resource associations must load")
	if view.terrain.resource_code(-128) != 128 or view.terrain.resource_code(-105) != 151:
		failures.append("Signed scenery bytes must map to original unsigned resources")
	if view.network.snapshot() != before:
		failures.append("Artwork must not mutate map topology")
	view.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: native authored terrain, signed scenery, city art and unchanged source map")
	quit(0 if failures.is_empty() else 1)

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../tasks/validation/terrain-" + label + ".png")
	root.get_texture().get_image().save_png(path)
