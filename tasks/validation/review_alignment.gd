extends SceneTree

# Opens the corrected map paused. Main preserves unsupported legacy save files.
func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.low_processor_usage_mode = false
	var app = load("res://scripts/main.gd").new()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	app.session.paused = true
	app._open_panel("map")
	app.world_view.update_train()
	app.world_view.zoom = 1.0 # source: authored inspection scale used by capture_map.gd.
	app.world_view.center_on_train()
	root.title = "Transartica - test des wagons sur les rails"
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../tasks/validation/modular-train-owner-save.png"))
	print("READY: modular train map open, paused; saved file preserved")
	OS.low_processor_usage_mode = true
