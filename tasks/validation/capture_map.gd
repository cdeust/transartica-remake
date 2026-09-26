extends SceneTree
# Validation capture: opens the map, drives the train, saves screenshots.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.low_processor_usage_mode = false
	root.size = Vector2i(1600, 1000)
	var app = load("res://scripts/main.gd").new()
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/capture-save.json")
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	await process_frame
	await process_frame
	app._restart_engine()
	app.engine.heat = 2500
	app.engine.pressure_reserve = 15000
	app.engine.regulator = 300
	app.engine.lignite_rate = 1
	app._open_panel("map")
	for i in 10:
		await process_frame
	await _shot("map-start")
	for step in 60:
		app.session.advance(1.0)
	app.world_view._visual_initialized = false
	app.world_view.update_train()
	for i in 5:
		await process_frame
	await _shot("map-east")
	for step in 110:
		app.session.advance(1.0)
	app.world_view._visual_initialized = false
	app.world_view.update_train()
	for i in 5:
		await process_frame
	await _shot("map-diagonal")
	app.world_view.zoom = 0.5
	app.world_view.center_on_train()
	for i in 5:
		await process_frame
	await _shot("map-overview")
	quit(0)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../.cache/%s.png" % name)
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
