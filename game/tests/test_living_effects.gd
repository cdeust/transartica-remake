extends SceneTree

# MIT. Source-model invariance, complete event delivery and visual clock contracts.
const Effects = preload("res://scripts/living_effects.gd")
const Combat = preload("res://scripts/tactical_combat.gd")
var failures: Array[String] = []


func _initialize() -> void:
	var effects_script: Script = Effects
	var combat_script: Script = Combat
	if not effects_script.can_instantiate() or not combat_script.can_instantiate():
		quit(1)
		return
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)


func fresh():
	var wagons = preload("res://scripts/train_wagons.gd").new()
	wagons.wagons.append([11,0,0,0])
	wagons.wagons.append([12,0,0,0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 420 # source: existing test_tactical_combat fixture.
	var model = Combat.new()
	model.begin(wagons,47,rng)
	model.offsets = [448,448]
	model.fire(7)
	model.fire(8)
	return model


func run() -> void:
	_model_invariance()
	_atlas_regions()
	_visual_rates()
	_combat_visual_rates()
	_cache_lifecycle()
	_peak_budget()
	for failure in failures: push_error(failure)
	if failures.is_empty():
		print("PASS: independent visual RNG, complete multi-tick weapon events,30/60/144Hz particles, pause/options/restart and bounded peak effects")
	quit(0 if failures.is_empty() else 1)


func _model_invariance() -> void:
	var baseline = fresh()
	var model = fresh()
	var effects = Effects.new()
	var received := []
	model.presentation_event_requested.connect(func(event):
		received.append(event.duplicate(true))
		effects.add(event.kind,Vector2(160,80)))
	baseline.advance(Combat.STEP_SECONDS*3)
	model.advance(Combat.STEP_SECONDS*3)
	check(received.any(func(e):return e.kind == "cannon"),"first tick cannon muzzle survives multi-tick advance")
	check(received.any(func(e):return e.kind == "machinegun"),"machinegun muzzle survives multi-tick advance")
	check(received.any(func(e):return e.kind == "impact"),"actual subsequent cannon impact delivered")
	for tick in 120:
		baseline.step()
		model.step()
		effects.advance(Combat.STEP_SECONDS)
	check(JSON.stringify(baseline.snapshot()) == JSON.stringify(model.snapshot()),"presentation leaves complete model and gameplay RNG identical")


func _atlas_regions() -> void:
	var atlas = Effects.new().atlas
	check(atlas.load_art(),"complete measured authored atlas loads")
	for group in ["flame","smoke","muzzle","rocket"]:
		for index in 4: check(atlas.regions.has("%s-%d" % [group,index]),"authored animation frame available")


func _visual_rates() -> void:
	var snapshots := []
	for rate in [30,60,144]:
		var effects = Effects.new()
		effects.add("destroy",Vector2(160,80))
		effects.add("cannon",Vector2(100,40),Vector2.DOWN)
		for frame in rate*2: effects.advance(1.0/rate)
		snapshots.append(JSON.stringify([effects.emitters,effects.particles.items]))
	check(snapshots[0] == snapshots[1] and snapshots[1] == snapshots[2],"same seeded effects identical after2seconds at30/60/144Hz")


func _cache_lifecycle() -> void:
	var scene = preload("res://scripts/tactical_scene.gd").new()
	root.add_child(scene)
	var first = fresh()
	scene.open_battle(first)
	scene.living.add("destroy",Vector2(160,80))
	scene.paused = true
	var before := JSON.stringify(scene.living.particles.items)
	scene._physics_process(1)
	check(JSON.stringify(scene.living.particles.items) == before,"paused effects freeze")
	scene.hide()
	scene.paused = false
	scene._physics_process(1)
	check(JSON.stringify(scene.living.particles.items) == before,"OPTIONS-hidden effects freeze")
	scene.open_battle(first)
	check(JSON.stringify(scene.living.particles.items) == before,"same battle preserves visual continuation")
	var second = fresh()
	scene.open_battle(second)
	check(scene.living.emitters.is_empty() and scene.living.particles.items.is_empty(),"new battle clears all particles")
	check(not first.presentation_event_requested.is_connected(scene._presentation_event),"old battle event subscription removed")
	scene.free()


func _combat_visual_rates() -> void:
	var snapshots := []
	for rate in [30,60,144]:
		var scene = preload("res://scripts/tactical_scene.gd").new()
		root.add_child(scene)
		scene.open_battle(fresh())
		for frame in rate*2: scene._physics_process(1.0/rate)
		snapshots.append(JSON.stringify([scene.living.emitters,scene.living.particles.items]))
		scene.free()
	check(snapshots[0] == snapshots[1] and snapshots[1] == snapshots[2],"actual source-triggered combat effects match at30/60/144Hz")


func _peak_budget() -> void:
	var effects = Effects.new()
	for index in Effects.MAX_EMITTERS*2:
		effects.add("destroy",Vector2(index%320,100))
	check(effects.emitters.size() == Effects.MAX_EMITTERS,"emitter budget enforced")
	check(effects.particles.items.size() == effects.particles.LIMIT,"particle budget enforced")
	effects.clear()
	check(effects.emitters.is_empty() and effects.particles.items.is_empty() and effects.remainder == 0,"clear releases complete visual working set")
