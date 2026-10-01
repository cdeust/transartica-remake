extends SceneTree
# requires-native-renderer
# MIT. Actual model-fired gun and planted-charge visual proof, not synthetic blasts.
const Combat = preload("res://scripts/tactical_combat.gd")
var scene
var model


func _initialize() -> void:
	OS.low_processor_usage_mode = false
	call_deferred("run")


func run() -> void:
	root.size = Vector2i(1280,800)
	var wagons = preload("res://scripts/train_wagons.gd").new()
	wagons.wagons.append([11,0,0,0])
	wagons.wagons.append([12,0,0,0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 420 # source: existing tactical weapon fixture.
	model = Combat.new()
	model.begin(wagons,47,rng)
	model.offsets = [448,448]
	scene = preload("res://scripts/tactical_scene.gd").new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scene)
	scene.open_battle(model)
	scene.set_physics_process(false)
	await process_frame
	assert(scene.living.atlas.load_art())
	assert(model.fire(7) and model.fire(8))
	scene._physics_process(Combat.STEP_SECONDS)
	await capture("cannon-muzzle")
	scene._physics_process(Combat.STEP_SECONDS)
	await capture("cannon-impact-machinegun")
	var actor = model.add_actor(0,29,-1,5,false,1,8)
	assert(model.plant(actor.id,1))
	for sweep in 5:
		model.scan_side = 0
		model.scan = model.columns*7-1
		scene._physics_process(Combat.STEP_SECONDS)
	assert(model.trains[1][7].health == 0)
	await capture("dynamite-destruction")
	for tick in 3: scene._physics_process(Combat.STEP_SECONDS)
	await capture("dynamite-rolling-flame")
	for tick in 22: scene._physics_process(Combat.STEP_SECONDS)
	await capture("persistent-smoke")
	scene.paused = true
	var particles := JSON.stringify(scene.living.particles.items)
	scene._physics_process(1)
	assert(particles == JSON.stringify(scene.living.particles.items))
	scene.queue_free()
	await process_frame
	print("PASS: native actual cannon muzzle/impact, machinegun tracers, planted dynamite destruction and persistent smoke; pause freezes visuals")
	quit()


func capture(label: String) -> void:
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../tasks/validation/living-"+label+"-native-20261001.png")
	assert(root.get_texture().get_image().save_png(path) == OK)
