extends SceneTree

# Interactive native review fixture for owner control of tactical movement.
# No claim of natural campaign progression: the train adds source cannon, MG
# and a livestock wagon (type7) so infantry and mammoths can be commanded.
func _initialize() -> void:
	OS.low_processor_usage_mode = false
	call_deferred("_run")

func _run() -> void:
	root.title = "Transartica tactical interactive review"
	var state = preload("res://scripts/tactical_combat.gd").new()
	var Wagons = preload("res://scripts/train_wagons.gd")
	var wagons = Wagons.new()
	wagons.wagons.append([11, 0, 0, 0])
	wagons.wagons.append([12, 0, 0, 0])
	var livestock := [0, 0, 0, 0]
	livestock[Wagons.TYPE] = 7
	livestock[Wagons.QUANTITY] = 5
	wagons.wagons.append(livestock)
	var rng := RandomNumberGenerator.new()
	rng.seed = 420 # source: reproducible test_tactical_combat fixture.
	state.begin(wagons, 47, rng)
	var scene = preload("res://scripts/tactical_scene.gd").new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scene)
	scene.open_battle(state)
	for index in state.trains[0].size():
		if state.trains[0][index].class == state.Setup.LIVESTOCK:
			scene.selected_wagon = index
			scene.camera = 128 + state.offsets[0] - index * 64
	scene.completed.connect(func(): print("Battle outcome ", state.outcome); quit())
