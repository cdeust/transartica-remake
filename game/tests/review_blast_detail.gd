extends SceneTree
# requires-native-renderer
# MIT. Same actual source charge/guns, frame-by-frame artistic comparison.
const Combat = preload("res://scripts/tactical_combat.gd")
var scene
var model
var directory: String

func _initialize() -> void:
	OS.low_processor_usage_mode = false
	directory = OS.get_environment("TRANSARTICA_BLAST_CAPTURE")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("res://../.cache/blast-after")
	DirAccess.make_dir_recursive_absolute(directory)
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,800)
	var wagons = preload("res://scripts/train_wagons.gd").new()
	wagons.wagons.append([11,0,0,0])
	wagons.wagons.append([12,0,0,0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 420 # Existing tactical comparison seed, unchanged before/after.
	model = Combat.new()
	model.begin(wagons,47,rng)
	model.offsets = [448,448]
	scene = preload("res://scripts/tactical_scene.gd").new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scene)
	var forced := OS.get_environment("TRANSARTICA_COMBAT_PACE") # 1 = source-parity capture
	if not forced.is_empty(): scene.pace = float(forced)
	scene.open_battle(model)
	scene.set_physics_process(false)
	assert(model.fire(7) and model.fire(8))
	for frame in 180: # Authored 3.6s observation, fixed source50Hz samples.
		if frame == 12:
			var actor = model.add_actor(0,29,-1,5,false,1,8)
			assert(model.plant(actor.id,1))
		if frame >= 12 and model.trains[1][7].health > 0:
			model.scan = model.columns*6-1
		scene._physics_process(1.0/50.0)
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(directory+"/%04d.png" % frame) == OK)
	assert(model.trains[1][7].health == 0)
	var file := FileAccess.open(directory+"/model.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(model.snapshot(),"\t"))
	file.close()
	scene.queue_free()
	await process_frame
	print("PASS: captured180native50Hz samples of actual source guns and planted charge; destroyed wagon and final model snapshot retained")
	quit()
