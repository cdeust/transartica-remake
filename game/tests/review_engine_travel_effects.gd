extends SceneTree
# requires-native-renderer
# MIT. Actual Main drawing and source-state isolation; no time-based verdicts.
const Saves = preload("res://scripts/session_saves.gd")
var app
var failures := 0
var checks := 0
var completed := false

func _initialize() -> void:
	OS.low_processor_usage_mode = false
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../tasks/validation/living-"+label+"-native-20261001.png")) == OK,"native capture "+label)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await process_frame

func run() -> void:
	root.size = Vector2i(1440,900)
	app = load("res://scripts/main.gd").new()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/engine-travel-effects-native.SAV")
	root.add_child(app)
	app.set_process(false)
	await process_frame
	app._restart_engine()
	app.world_view.set_process(false)
	app.engine.heat = 1000
	app.engine.pressure_reserve = 500
	app.engine.lignite_rate = 1
	app.room_art.paused = false
	var before: Dictionary = Saves.snapshot(app)
	app.room_art.advance_visual(0.6)
	check(Saves.snapshot(app) == before,"furnace visual ticks preserve whole source session")
	check(app.room_art.living.effects.emitters.size() == 4,"two steam valves emit on two visual pulses")
	await capture("engine-furnace")
	var tick: int = app.room_art.living.tick
	await key(KEY_F6)
	app._process(0.0)
	check(app._boudoir_session.reception.visible and app.clock.paused,"actual OPTIONS blocks shared visual clock")
	app.room_art.advance_visual(0.6)
	check(app.room_art.living.tick == tick,"OPTIONS freezes furnace effects")
	app._open_panel("room")
	var world = app.world_view
	var travel_tick: int = world.living.tick
	world._process(0.6)
	check(world.living.tick == travel_tick,"hidden travel does not advance plumes")
	await travel(world)
	check(completed,"native travel coroutine completed")
	check(Saves.save(app,app.save_path_override).ok,"save actual warm engine session")
	check(Saves.restore(app,app.save_path_override).ok,"restore actual warm engine session")
	check(app.room_art.living.effects.emitters.is_empty() and app.room_art.living.effects.particles.items.is_empty(),"restore clears unrecorded furnace transients")
	check(world.living.effects.emitters.is_empty() and world.living.effects.particles.items.is_empty(),"restore clears old map-space transients")
	app.room_art.paused = false
	app.room_art.advance_visual(0.3)
	world.living.advance(world,0.3)
	app._restart_engine()
	check(app.room_art.living.effects.emitters.is_empty() and app.room_art.living.effects.particles.items.is_empty(),"new game discards prior boiler steam and embers")
	check(world.living.effects.emitters.is_empty() and world.living.effects.particles.items.is_empty(),"new game discards prior world-space train smoke")
	app.game_audio.stop_effects()
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://../.cache/engine-travel-effects-native.SAV"))
	print("PASS: native engine/travel "+str(checks)+" checks" if failures == 0 else "FAIL: native engine/travel "+str(failures)+"/"+str(checks))
	quit(failures)

func travel(world) -> void:
	app._open_panel("map")
	app._process(0.0)
	await process_frame
	await RenderingServer.frame_post_draw
	check(world._can_animate(),"actual travel visible and unpaused")
	var before: Dictionary = Saves.snapshot(app)
	world._process(0.3)
	check(Saves.snapshot(app) == before,"travel visual ticks preserve engine and journey source state")
	check(world.living.effects.emitters.size() == 2,"actual journey supplies both locomotive stacks")
	if world.living.effects.emitters.size() != 2:
		completed = true
		return
	var points: Array = world.living.effects.emitters.map(func(e):return e.point)
	# Center the actual locomotive for the visual review, rather than retaining
	# the strategic-map camera where the nose can lie outside the window.
	var pose: Dictionary = world.train_renderer.poses(world,world.journey,world.consist,0.0)[0]
	world.camera_world = pose.center+Vector2.ONE*0.5
	world.offset = Vector2.ZERO
	world.inspecting_map = true
	world.following_train = false
	world.living.advance(world,0.6)
	for zoom in [1.0,2.0]:
		world.zoom = zoom
		world.queue_redraw()
		for point in points:
			var projected: Vector2 = world.size*0.5+world.offset+(point-world._project(world.camera_world))*zoom
			var position: Vector2 = Vector2(point.x/world.CELL_PIXELS,point.y/world.CELL_PIXELS)
			check(projected.is_equal_approx(world._world_to_screen(position)),"plume and train share camera/zoom projection")
		await capture("travel-plume-zoom"+str(int(zoom)))
		check(world._world_to_screen(pose.center+Vector2.ONE*0.5).is_equal_approx(world.size*0.5),"native review remains centered on the locomotive")
	world.camera_world += Vector2(0.5,0.5)
	world.queue_redraw()
	check(points == world.living.effects.emitters.slice(0,2).map(func(e):return e.point),"camera pan never moves world-attached emitter origins")
	await capture("travel-plume-pan")
	var tick: int = world.living.tick
	await key(KEY_F6)
	app._process(0.0)
	world._process(0.6)
	check(world.living.tick == tick,"OPTIONS freezes travel smoke clock")
	completed = true
