extends SceneTree
# MIT. Actor presentation motion: continuous glides at the source cadence,
# facing, plant crouch, melee read-out, removal fade, and an unchanged model.
const Scene = preload("res://scripts/tactical_scene.gd")
const Combat = preload("res://scripts/tactical_combat.gd")
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func battle() -> Combat:
	var wagons = preload("res://scripts/train_wagons.gd").new()
	wagons.wagons.append([11,0,0,0])
	wagons.wagons.append([12,0,0,0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 420 # source: existing tactical fixture
	var model := Combat.new()
	model.begin(wagons,47,rng)
	return model

func populate(model: Combat) -> void:
	model.actors.clear()
	model.add_actor(0,12,3,5,false,-1,2) # walks right
	model.add_actor(0,30,2,5,false,-1,6) # walks left
	model.add_actor(0,20,4,3,false,-1,8)
	model.add_actor(1,22,4,6,false,-1,6) # closes on the stationary group

func run() -> void:
	var scene = Scene.new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scene)
	var model := battle()
	populate(model)
	var bare := battle()
	populate(bare)
	scene.open_battle(model)
	scene.set_physics_process(false)
	await process_frame
	var walker: int = model.actors[0].id
	var left: int = model.actors[1].id
	var previous: Vector2 = scene.actor_motion.point(scene,model.actors[0])
	var largest := 0.0
	var travelled := 0.0
	var melee_seen := false
	var hit_seen := false
	for frame in 50*12: # source: twelve seconds at the shared 50Hz step
		scene._physics_process(0.02)
		bare.advance(0.02*scene.pace)
		for actor in model.actors:
			if actor.id == walker:
				var now: Vector2 = scene.actor_motion.point(scene,actor)
				largest = maxf(largest,absf(now.x-previous.x))
				travelled += now.x-previous.x
				previous = now
		for track in scene.actor_motion.tracks.values():
			if track.lunge > 0: melee_seen = true
			if track.hit > 0: hit_seen = true
	# Glide: no16px cell jumps, steady rightward progress.
	check(largest < 1.0,"walker never jumps a cell (max %.2fpx/frame)" % largest)
	check(travelled > 16.0,"walker progressed across cells (%.1fpx)" % travelled)
	check(scene.actor_motion.tracks[walker].facing > 0,"right walker faces right")
	check(scene.actor_motion.tracks[left].facing < 0,"left walker is mirrored")
	check(melee_seen and hit_seen,"melee shows a lunge and a hit flash")
	# Presentation never writes the model.
	check(JSON.stringify(model.snapshot()) == JSON.stringify(bare.snapshot()),"scene-driven model equals bare model")
	# A stopped group finishes its stride and stands within half a second.
	var stopper: Dictionary = model.actors[1]
	stopper.direction = 8
	for frame in 50*3: scene._physics_process(0.02) # finish the current glide
	check(not scene.actor_motion.moving(scene.actor_motion.tracks[stopper.id]),"stopped group stands")
	# A restore-like jump snaps instead of sliding across the field.
	stopper.x += 10
	scene._physics_process(0.02)
	check(scene.actor_motion.shown_cell(scene.actor_motion.tracks[stopper.id]).x == stopper.x,"discontinuity snaps")
	# Removal fades over FADE then the track is released.
	var gone: Dictionary = model.actors[0]
	gone.count = 0
	model.actors.erase(gone)
	scene._physics_process(0.02)
	check(scene.actor_motion.tracks.has(gone.id) and scene.actor_motion.tracks[gone.id].fade > 0,"removed group fades")
	for frame in 30: scene._physics_process(0.02)
	check(not scene.actor_motion.tracks.has(gone.id),"faded group released")
	# A real player plant crouches the planting group.
	var planter = model.add_actor(0,29,-1,5,false,1,8)
	scene._physics_process(0.02)
	check(model.plant(planter.id,1),"real charge planted")
	scene._physics_process(0.02)
	check(scene.actor_motion.tracks[planter.id].crouch > 0,"planting group crouches")
	if failures.is_empty():
		print("PASS: continuous actor glides, facing, plant crouch, melee lunge/hit, removal fade, model untouched")
	else:
		for failure in failures: push_error(failure)
	quit()
