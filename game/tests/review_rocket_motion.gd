extends SceneTree
# requires-native-renderer
# MIT. Every50Hz presented frame of the actual source launch (motion review).
# Source snapshots are sampled at each BERTA60ms boundary for equality checks.
const Saves = preload("res://scripts/session_saves.gd")
var app
var failures := 0
var checked := 0
var snapshots := []
var directory: String

func _initialize() -> void:
	OS.low_processor_usage_mode = false
	directory = OS.get_environment("TRANSARTICA_BLAST_CAPTURE")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("res://../.cache/rocket-motion")
	DirAccess.make_dir_recursive_absolute(directory)
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checked += 1
	if not value:
		failures += 1
		push_error(label)

func run() -> void:
	root.size = Vector2i(1440,900)
	app = load("res://scripts/main.gd").new()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.save_path_override = directory+"/rocket-motion.SAV"
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
	launcher.pace_enabled = OS.get_environment("TRANSARTICA_LAUNCH_PACE") == "1" # default: source-parity capture
	check(launcher.action(108),"actual FIRE")
	var frame := 0
	var phases := ["launch","ascent","flight","impact"] if launcher.pace_enabled else ["launch","ascent"]
	while launcher.model.phase in phases and frame < 900:
		if frame%3 == 0:
			snapshots.append({"model":launcher.model.snapshot(),"engine":app.engine.snapshot(),"wagons":app.wagons.snapshot(),"enemies":app.encounters.enemies.snapshot(),"rng":app._trade_rng.state})
		launcher.scene._physics_process(1.0/50.0)
		launcher.scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(directory+"/%04d.png" % frame) == OK,"capture")
		frame += 1
	FileAccess.open(directory+"/states.json",FileAccess.WRITE).store_string(JSON.stringify(snapshots))
	app.game_audio.stop_effects()
	app.queue_free()
	await process_frame
	print("PASS: rocket motion ",frame," frames ",checked," checks" if failures == 0 else " FAIL "+str(failures))
	quit(failures)
