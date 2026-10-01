extends SceneTree
# MIT. Modern continuous visual timing; source state and event boundaries unchanged.
const Existing = preload("res://tests/test_living_effects.gd")
const Scene = preload("res://scripts/tactical_scene.gd")
var failures: Array[String] = []

func _initialize() -> void:
	var script: Script = Scene
	if not script.can_instantiate(): quit(1); return
	call_deferred("run")

func snapshot(scene) -> String:
	return JSON.stringify([scene.living.emitters,scene.living.particles.items,scene.living.volume.snapshot(),scene.weapon_motion.rigs])

func make_scene():
	var fixture = Existing.new()
	var model = fixture.fresh()
	fixture.free()
	var scene = Scene.new()
	root.add_child(scene)
	scene.open_battle(model)
	scene.set_physics_process(false)
	return scene

func check(condition: bool, label: String) -> void:
	if not condition: failures.append(label)

func run() -> void:
	var scene = make_scene()
	scene.living.add("destroy",Vector2(160,80))
	var before := snapshot(scene)
	scene._physics_process(1.0/50.0)
	check(scene.state.ticks == 0,"visual subframe does not advance source combat tick")
	check(snapshot(scene) != before and scene.living.emitters[0].age == 1,"granular motion advances between source ticks")
	scene.paused = true
	before = snapshot(scene)
	scene._physics_process(1)
	check(snapshot(scene) == before,"pause freezes gas, fragments and weapon rigs")
	scene.free()
	var batched = make_scene()
	var sliced = make_scene()
	batched._physics_process(3.0*batched.state.STEP_SECONDS)
	for i in 12: sliced._physics_process(1.0/50.0)
	var batch_state: Dictionary = batched.state.snapshot()
	var slice_state: Dictionary = sliced.state.snapshot()
	var fixture = Existing.new()
	var control = fixture.fresh()
	fixture.free()
	control.advance(3.0*control.STEP_SECONDS*batched.pace) # owner pace: same ticks, shorter real time
	check(JSON.stringify(batch_state) == JSON.stringify(control.snapshot()),"one model advance preserves exact complete source snapshot/RNG")
	print("source remainder batched=",batch_state.get("remainder")," sliced=",slice_state.get("remainder"))
	check(is_equal_approx(batch_state.remainder,slice_state.remainder),"source accumulator agrees to its existing float comparison")
	batch_state.erase("remainder")
	slice_state.erase("remainder")
	check(JSON.stringify(batch_state) == JSON.stringify(slice_state),"batched source model/RNG matches twelve visual slices")
	check(snapshot(batched) == snapshot(sliced),"batched event births preserve the same visual ages")
	var expected := roundi((3.0*batched.state.STEP_SECONDS-batched.state.STEP_SECONDS/batched.pace)/batched.living.STEP)
	check(batched.living.emitters.any(func(e):return e.kind == "cannon" and e.age == expected),"first source cannon event is born at the first paced tick boundary")
	batched.free()
	sliced.free()
	var snapshots := []
	for rate in [30,60,144]:
		scene = make_scene()
		for frame in rate*2: scene._physics_process(1.0/rate)
		snapshots.append(snapshot(scene))
		scene.free()
	check(snapshots[0] == snapshots[1] and snapshots[1] == snapshots[2],"volume and weapon rig states match30/60/144 displayHz")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS:50Hz sub-tick granular motion, pause, correctly aged batched source births and30/60/144Hz volume/weapon states")
	quit(0 if failures.is_empty() else 1)
