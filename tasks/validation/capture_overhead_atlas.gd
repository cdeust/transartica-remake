extends SceneTree

# Native (non-headless) capture of the 25-drawing overhead atlas
# (tools/build_overhead_atlas.py) integrated in the real game (tasks/todo.md, "Decision : train en vue de dessus"). Uses the
# real application scene, the real 46-city map and the real wagons/consist
# derivation; no synthetic fixture. Not headless: the earlier owner incident
# with a sandboxed headless RotatedFileLogger crash (tasks/lessons.md) means
# this must run with an escalated, non-sandboxed launch and an explicit
# absolute --log-file.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.low_processor_usage_mode = false
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	root.size = Vector2i(1400, 820)
	root.content_scale_size = root.size
	root.title = "Transartica - overhead atlas integration"
	await process_frame
	await process_frame
	app.session.paused = true
	app._open_panel("map")
	app.world_view.zoom = 1.6
	app.world_view.follow_train()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../tasks/validation/overhead-atlas-straight.png"))
	print("READY: straight segment captured")

	# Advance the real journey with the engine's own tick mechanics
	# (train_journey.gd::advance) until its heading actually changes, rather
	# than teleporting the position. Measured: the decoded route leaves its
	# initial EAST heading after 86 ticks, at (39,62) heading SOUTH-EAST.
	var start_heading: int = app.journey.heading
	var ticks := 0
	while app.journey.heading == start_heading and ticks < 2000 and not app.journey.blocked:
		app.journey.advance(450)
		ticks += 1
	app.world_view.zoom = 0.4 # zoom out: show the whole six-car consist through the bend, not just the clipped nose.
	app.world_view.center_on_train()
	app.world_view.update_train()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../tasks/validation/overhead-atlas-curve.png"))
	print("READY: curve captured after %d real advance() ticks, position=%s heading=%s" % [ticks, app.journey.position, app.journey.heading_name()])

	# Real purchase path: append a mapped wagon type the same way
	# city_trade.gd::buy_wagons does, then go through the real signal handler
	# (main.gd::_on_cargo_changed) so composition is re-derived exactly as a
	# workshop visit would trigger it.
	# Four of the 19 types that had no drawing before the catalogue atlas.
	for type_id in [11, 16, 14, 8]: # CANNON, CRANE, TANK, THE DRILL
		app.wagons.wagons.append([type_id, 0, 0, 0])
	app._on_cargo_changed()
	# The new tail wagon has no path history until the train moves past its
	# own length (tasks/lessons.md: wagons "emerge as the train moves away").
	ticks = 0
	while ticks < 1500:
		app.journey.advance(450)
		ticks += 1
	app.world_view.center_on_train() # re-center for the now ten-car consist.
	app.world_view.update_train()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../tasks/validation/overhead-atlas-after-purchase.png"))
	print("READY: post-purchase captured, consist=%s, drawn poses=%d" % [app.world_view.consist.vehicles, app.world_view.train_renderer.poses(app.world_view, app.journey, app.world_view.consist, 0.0).size()])
	OS.low_processor_usage_mode = true
	quit(0)
