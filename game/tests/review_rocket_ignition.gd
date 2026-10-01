extends SceneTree
# requires-native-renderer
# MIT. Source-valid equipment fixture; exact original BERTA callbacks.
const Saves = preload("res://scripts/session_saves.gd")
var app
var failures := 0
var checked := 0
var snapshots := []
var tag := "after"
var paused_checked := false

func _initialize() -> void:
	OS.low_processor_usage_mode = false
	if "--before" in OS.get_cmdline_user_args(): tag = "before"
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checked += 1
	if not value:
		failures += 1
		push_error(label)

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../tasks/validation/rocket-ignition-"+tag+"-"+label+".png")) == OK,"capture "+label)

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
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/rocket-ignition.SAV")
	root.add_child(app)
	app.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	app._trade_rng.seed = 420 # Existing tactical test fixture seed.
	app._restart_engine()
	app.set_process(false)
	app.world_view.set_process(false)
	app.wagons.wagons.append([13,0,0,0])
	app.wagons.wagons.append([14,0,2,2])
	var origin: Vector2i = app.journey.position
	app.encounters.enemies.slots[0] = [1,origin.x-40,origin.y-7,2,0,0,0,10]
	var launcher = app._boudoir_session.launcher
	check(launcher.open() and launcher.action(107),"actual ARM")
	launcher.scene.set_physics_process(false)
	for tick in 5: launcher.advance(3.0/50.0)
	launcher.pace_enabled = false # source-parity capture: one BERTA step per60ms
	check(launcher.action(108),"actual FIRE")
	var step := 0
	while launcher.model.phase in ["launch","ascent"]:
		var before: Dictionary = launcher.model.snapshot()
		launcher.scene.living.observe(launcher.model,0.0,launcher.scene._exhaust_point(launcher.model))
		check(before == launcher.model.snapshot(),"presentation preserves source state")
		snapshots.append({"model":before,"engine":app.engine.snapshot(),"wagons":app.wagons.snapshot(),"enemies":app.encounters.enemies.snapshot(),"rng":app._trade_rng.state})
		if step in [0,3,8,15,18,23]:
			launcher.scene.queue_redraw()
			await capture("step%02d" % step)
		if tag == "after" and step == 8:
			await pause_review(launcher)
		launcher.scene._physics_process(3.0/50.0)
		step += 1
	var path := ProjectSettings.globalize_path("res://../tasks/validation/rocket-ignition-"+tag+"-states.json")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(snapshots))
	check(tag == "before" or paused_checked,"native pause coroutine completed")
	app.game_audio.stop_effects()
	app.queue_free()
	await process_frame
	print("PASS: rocket ignition ",tag," ",checked," native assertions" if failures == 0 else " FAIL "+str(failures))
	quit(failures)

func pause_review(launcher) -> void:
	var state: Dictionary = launcher.model.snapshot()
	var tick: int = launcher.scene.living.ignition.tick
	await key(KEY_P)
	check(launcher.paused,"native P pauses launch")
	launcher.scene._physics_process(0.6)
	check(state == launcher.model.snapshot() and launcher.scene.living.ignition.tick == tick,"pause freezes source and continuous jet")
	await capture("pause")
	await key(KEY_P)
	check(not launcher.paused,"native P resumes")
	paused_checked = true
