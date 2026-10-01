extends SceneTree

# Native renderer review fixture; no claim of natural campaign progression.
func _initialize() -> void:
	OS.low_processor_usage_mode = false
	call_deferred("_run")

func _run() -> void:
	root.title = "Transartica tactical scene review"
	var state = preload("res://scripts/tactical_combat.gd").new()
	var wagons = preload("res://scripts/train_wagons.gd").new()
	wagons.wagons.append([11, 0, 0, 0]) # source: fixture adds source cannon and MG.
	wagons.wagons.append([12, 0, 0, 0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 420 # source: reproducible test_tactical_combat fixture.
	state.begin(wagons, 47, rng)
	var scene = preload("res://scripts/tactical_scene.gd").new()
	scene.size = root.get_visible_rect().size
	root.add_child(scene)
	scene.open_battle(state)
	scene.paused = true
	await process_frame
	# Camera positions only select authored wagon visibility, not game state.
	scene.camera = state.offsets[0] - 320
	scene.queue_redraw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../tasks/validation/tactical-native-20260930.png"))
	scene.queue_free()
	await process_frame
	print("PASS: tactical scene captured with native renderer")
	quit()
