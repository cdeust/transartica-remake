extends SceneTree
# requires-native-renderer
# MIT. Actual Main scene, source-valid equipment and real BERTA controls.
const Saves = preload("res://scripts/session_saves.gd")
var app
var checks := 0
var failures := 0
var mine_complete := false
var works_complete := false


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
	var path := ProjectSettings.globalize_path("res://../tasks/validation/living-"+label+"-native-20261001.png")
	check(root.get_texture().get_image().save_png(path) == OK,"native capture "+label)


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
	root.size = Vector2i(1280,800)
	app = load("res://scripts/main.gd").new()
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/ambience-native.SAV")
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	app.set_process(false)
	await process_frame
	app._restart_engine()
	var launcher = app._boudoir_session.launcher
	launcher.scene.set_physics_process(false)
	app.wagons.wagons.append([13,0,0,0])
	app.wagons.wagons.append([14,0,2,2])
	var origin: Vector2i = app.journey.position
	app.encounters.enemies.slots[0] = [1,origin.x-40,origin.y-7,2,0,0,0,10]
	check(launcher.open() and launcher.action(107),"production launcher and ARM")
	for tick in 5: launcher.advance(3.0/50.0)
	check(launcher.action(108),"production FIRE")
	var phases := {}
	while launcher.model.phase != "report":
		var phase: String = launcher.model.phase
		if not phases.has(phase):
			# Observe independently before source advances, then render the scene.
			var before: Dictionary = Saves.snapshot(app)
			launcher.scene.living.observe(launcher.model,0.02,launcher.scene._exhaust_point(launcher.model))
			check(Saves.snapshot(app) == before,"observer preserves complete saved state and RNG "+phase)
			launcher.scene.queue_redraw()
			await capture("rocket-"+phase)
			phases[phase] = true
		launcher.scene._physics_process(3.0/50.0)
	check(phases.has("impact") and launcher.model.status == 2,"real homing impact reached")
	await capture("rocket-report")
	var effects = launcher.scene.living.effects
	var clock: float = effects.remainder
	var emitters: Array = effects.emitters.duplicate(true)
	var particles: Array = effects.particles.items.duplicate(true)
	await key(KEY_F6)
	check(launcher.paused and app._boudoir_session.reception.visible,"native OPTIONS pauses source launcher")
	launcher.scene._physics_process(1.0)
	check(effects.remainder == clock and effects.emitters == emitters and effects.particles.items == particles,"OPTIONS freezes complete effects clock")
	app._open_panel("room")
	check(Saves.save(app,app.save_path_override).ok,"save paused visible launcher")
	check(Saves.restore(app,app.save_path_override).ok,"restore paused visible launcher")
	check(launcher.paused and launcher.scene.visible,"paused restored launcher stays visible and paused")
	check(launcher.scene.living.effects.emitters.is_empty() and launcher.scene.living.effects.particles.items.is_empty(),"restored paused launcher clears previous missile transients")
	launcher.dismiss()
	app._open_panel("map")
	await mine()
	await works()
	check(mine_complete and works_complete,"all native worksite cases completed")
	app.game_audio.stop_effects()
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://../.cache/ambience-native.SAV"))
	print("PASS: native ambience "+str(checks)+" checks" if failures == 0 else "FAIL: native ambience "+str(failures)+"/"+str(checks))
	quit(failures)


func mine() -> void:
	# Existing production mine screen. Prospecting data is illustrative here;
	# source mine mutation remains covered by test_world_actions.gd.
	var screen = app._world_session.mine_screen
	screen.set_physics_process(false)
	screen.open_mine({"ore":"ANTHRACITE","year":2714,"wealth":45})
	screen._physics_process(0.02)
	check(screen.ambience.effects.emitted == 0,"mine question has no work emission")
	screen.show_mine()
	var before: Dictionary = Saves.snapshot(app)
	screen._physics_process(0.4)
	check(Saves.snapshot(app) == before,"mine art leaves saved model and RNG untouched")
	await capture("mine-work")
	var clock: float = screen.ambience.time
	app._open_panel("options")
	screen._physics_process(1.0)
	check(screen.ambience.time == clock,"OPTIONS freezes mine lamps and dust")
	screen.hide()
	app._open_panel("map")
	mine_complete = true


func works() -> void:
	var scene = app.works_dialog
	scene.set_physics_process(false)
	check(app.journey.restore({"version":1,"position":[82,67],"heading":6,"distance_ticks":0,"phase":0,"blocked":false}),"source crevasse fixture")
	app.wagons.wagons.append([18,0,1,25])
	app.wagons.wagons.append([6,0,0,20])
	check(scene.ask(app.network),"actual works question")
	scene._accept()
	check(scene._ok_result and scene.countdown > 0,"actual accepted source work")
	var before: Dictionary = Saves.snapshot(app)
	scene._physics_process(0.4)
	check(Saves.snapshot(app) == before,"work art leaves rail debit, countdown and RNG untouched")
	check(scene.ambience.effects.emitters.size() == 2,"accepted works dust and sparks integrated")
	await capture("track-work")
	var clock: float = scene.ambience.time
	app._open_panel("options")
	scene._physics_process(1.0)
	check(scene.ambience.time == clock,"OPTIONS freezes work effects")
	scene.hide()
	works_complete = true
