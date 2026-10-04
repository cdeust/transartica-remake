extends SceneTree
# MIT. Source: WDECOR4fca/4feb computes first visible wagon from the camera;
# 5420 executes exactly six player slots, while17b4 executes all enemy weapons.
const Combat = preload("res://scripts/tactical_combat.gd")
const Weapons = preload("res://scripts/tactical_weapons.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _run() -> void:
	var wagons = preload("res://scripts/train_wagons.gd").new()
	wagons.wagons.append([11,0,0,0])
	wagons.wagons.append([12,0,0,0])
	# A long convoy supplies legal movement room beyond the initial screen band.
	for index in 7:
		wagons.wagons.append([17,0,0,0])
	var state = Combat.new()
	var rng = RandomNumberGenerator.new()
	rng.seed = 420 # Existing tactical fixture seed, not a campaign mutation.
	state.begin(wagons,47,rng)
	state.offsets = [600,600] # Fixture: gun7 lies beyond the default screen.
	var scene = preload("res://scripts/tactical_scene.gd").new()
	root.add_child(scene)
	scene.open_battle(state)
	scene.hide() # This test exercises the scene camera, not synthetic wagon rendering.
	scene.paused = true
	scene.camera = 128 + state.offsets[0] - 7 * 64 # Source bar-centering4c10.
	check(state.fire(7), "Visible cannon accepts firing command")
	var health: int = state.trains[1][7].health
	Weapons.run(state)
	check(state.trains[1][7].health == health, "Source cannon23 is the muzzle flash")
	Weapons.run(state)
	check(state.trains[1][7].health == health-1, "Scrolling to the cannon enables its actual shot")
	check(state.trains[0][7].reload == 21, "Visible cannon reload advances through both source ticks")
	# Snapshot/new model must retain the same visibility and deterministic shot.
	var saved: Dictionary = state.snapshot()
	var restored = Combat.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(saved))), "Scrolled battle restores")
	check(restored.snapshot() == saved, "Scrolled battle round trip preserves camera and model")
	var legacy := saved.duplicate(true)
	legacy.erase("camera_offset")
	check(restored.restore(legacy), "Legacy battle without camera still restores")
	check(restored.snapshot().get("camera_offset",0) == 0, "Legacy camera defaults to original center")
	var bad := saved.duplicate(true)
	bad.camera_offset = INF
	var previous: Dictionary = restored.snapshot()
	check(not restored.restore(bad) and restored.snapshot() == previous, "Invalid camera is rejected atomically")
	# Camera at the opposite end hides the armed wagon, so its timer freezes.
	scene.camera = -state.center_offset()
	state.trains[0][7].reload = 23
	Weapons.run(state)
	check(state.trains[0][7].reload == 23, "Hidden player gun stays inactive")
	scene.camera = 128 + state.offsets[0] - 7 * 64
	for car in state.trains[0]:
		car.class = state.Setup.MACHINE_GUN
		car.reload = 13
	Weapons.run(state)
	check(state.trains[0].filter(func(car): return car.reload == 12).size() == 6, "Exactly six visible player slots advance")
	for index in state.trains[0].size():
		check(state.trains[0][index].reload == (12 if index in [5,6,7,8,9,10] else 13), "The camera activates the source six slots, including both boundaries")
	scene.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: camera selects six active player weapons; scrolled cannon fires, hidden gun freezes, saves restore")
	quit(0 if failures.is_empty() else 1)
