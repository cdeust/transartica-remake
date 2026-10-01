extends SceneTree

# MIT. Authored continuous visual clock is independent of BERTA callbacks/RNG.
const Ignition = preload("res://scripts/rocket_ignition.gd")
const Effects = preload("res://scripts/rocket_living_effects.gd")
const Model = preload("res://scripts/launcher_model.gd")
const Enemies = preload("res://scripts/enemy_trains.gd")
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	if not value: failures.append(label)

func run() -> void:
	var snapshots := []
	for rate in [30,60,144]:
		var ignition = Ignition.new()
		for frame in rate*2: ignition.observe(1.0/rate,Vector2(141,95),true)
		check(ignition.tick == 100,"independent50Hz continuous clock")
		snapshots.append([ignition.tick,ignition.nozzle,ignition.active])
	check(snapshots[0] == snapshots[1] and snapshots[1] == snapshots[2],"same visual clock at30/60/144Hz")
	var enemies = Enemies.new()
	enemies.slots[0] = [1,40,33,2,0,0,0,10]
	var model = Model.new()
	model.action(107,Vector2i(80,40),enemies)
	for tick in 5: model.step()
	check(model.action(108,Vector2i(80,40),enemies),"original source launch fixture")
	var effects = Effects.new()
	var before: Dictionary = model.snapshot()
	var enemy_before: Dictionary = enemies.snapshot()
	for visual_frame in 6: effects.observe(model,1.0/60,Vector2(141,103))
	check(effects.ignition.tick == 5,"visual ignition advances without source cursor changes")
	check(before == model.snapshot() and enemies.snapshot() == enemy_before,"visual ignition never advances gameplay")
	check(effects.effects.emitters.is_empty(),"launch has no discrete atlas exhaust puffs")
	model.phase = "flight"
	model.geometry = preload("res://scripts/launcher_geometry.gd").calculate(0,50,Vector2i(80,40),enemies)
	effects.observe(model,0.02,Vector2.ZERO)
	check(not effects.ignition.active,"map transition hides launch-pad field")
	for failure in failures: push_error(failure)
	print("PASS: rocket ignition continuous clock, source isolation and map transition" if failures.is_empty() else "FAIL: rocket ignition "+str(failures.size()))
	quit(0 if failures.is_empty() else 1)
