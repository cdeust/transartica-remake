extends SceneTree
# MIT. Actor presentation: sprint-then-wait at the source cadence, planted feet
# that never slide, facing, visible soldiers per strength, melee strikes,
# recoils and falling casualties, plant crouch, merge fade, unchanged model.
const Scene = preload("res://scripts/tactical_scene.gd")
const Combat = preload("res://scripts/tactical_combat.gd")
const Rig = preload("res://scripts/tactical_trooper_rig.gd")
const Poses = preload("res://scripts/tactical_trooper_poses.gd")
const Motion = preload("res://scripts/tactical_actor_motion.gd")
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

# World x of each planted foot of a soldier (logical px), keyed by leg.
func planted(scene, track: Dictionary, soldier: Dictionary) -> Dictionary:
	var result := {}
	if soldier.amp < 0.999: return result
	var rig := Rig.pose(soldier.phase,soldier.amp,0)
	var at: Vector2 = scene.actor_motion._place(scene,track.roof,soldier.cell,scene.actor_motion._offset(track,soldier))
	for leg in 2:
		if not rig.swing[leg] and fposmod(soldier.phase+PI*leg,TAU) > 0.05:
			result[leg] = {"x":at.x+track.facing*rig.feet[leg].x/Rig.PER,"stance":floori((soldier.phase+PI*leg)/TAU)}
	return result

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
	var motion = scene.actor_motion
	var fastest := 0.0
	var waited := 0
	var sprinted := 0
	var slip := 0.0
	var feet := {}
	var strike_seen := false
	var recoil_seen := false
	var falls_seen := false
	var previous := Vector2.INF
	for frame in 50*12: # source: twelve seconds at the shared 50Hz step
		scene._physics_process(0.02)
		bare.advance(0.02*scene.pace)
		if motion.tracks.has(walker):
			var track: Dictionary = motion.tracks[walker]
			var leader: Dictionary = track.soldiers[0]
			var now: Vector2 = motion.point(scene,track.actor)
			if previous != Vector2.INF: fastest = maxf(fastest,now.distance_to(previous))
			previous = now
			if leader.speed > Motion.SPRINT*0.8: sprinted += 1
			if leader.speed == 0 and leader.cell == track.to: waited += 1
			var down := planted(scene,track,leader)
			for leg in down:
				if feet.has(leg) and feet[leg].stance == down[leg].stance:
					slip = maxf(slip,absf(down[leg].x-feet[leg].x))
			feet = down
		for track in motion.tracks.values():
			for soldier in track.soldiers:
				if soldier.strike > 0: strike_seen = true
				if soldier.recoil > 0: recoil_seen = true
		for body in motion.bodies:
			if body.fall: falls_seen = true
	# Sprint then wait: real running speed, then standing for the next source step.
	check(fastest <= Motion.SPRINT*1.08*0.02+0.01,"no jump faster than the sprint (%.2fpx/frame)" % fastest)
	check(sprinted > 20 and waited > 20,"sprints (%d) and waits (%d) between source steps" % [sprinted,waited])
	check(slip < 0.05,"planted feet never slide (max %.3fpx)" % slip)
	check(motion.tracks[walker].facing > 0,"right walker faces right")
	check(motion.tracks[left].facing < 0,"left walker is mirrored")
	check(strike_seen and recoil_seen and falls_seen,"melee shows strikes, recoils and falling casualties")
	for track in motion.tracks.values():
		check(track.soldiers.size() == (1 if track.actor.mammoth else clampi(track.actor.count,1,Motion.VISIBLE)),"visible soldiers follow strength")
	# Presentation never writes the model.
	check(JSON.stringify(model.snapshot()) == JSON.stringify(bare.snapshot()),"scene-driven model equals bare model")
	# A stopped group comes to rest standing.
	var stopper: Dictionary = model.actors[1] if model.actors.size() > 1 else model.actors[0]
	stopper.direction = 8
	for frame in 50*3: scene._physics_process(0.02)
	check(not Motion.moving(motion.tracks[stopper.id]),"stopped group stands")
	# A restore-like jump snaps instead of sprinting across the field.
	stopper.x += 10
	scene._physics_process(0.02)
	check(motion.tracks[stopper.id].soldiers[0].cell.x == stopper.x,"discontinuity snaps")
	# A merge (no melee) fades its soldiers instead of felling them.
	var merged: Dictionary = stopper
	model.actors.erase(merged)
	var before: int = motion.bodies.size()
	scene._physics_process(0.02)
	var standing: Array = motion.bodies.slice(before).filter(func(body): return not body.fall)
	check(not standing.is_empty(),"merged group fades standing")
	for frame in 40: scene._physics_process(0.02)
	check(motion.bodies.filter(func(body): return not body.fall).is_empty(),"faded group released")
	# Presentation-only steps from here: the model is frozen so each sequence plays out.
	# A real player plant: the planter runs to the slot, kneels, sets and lights the box.
	var planter = model.add_actor(0,29,-1,5,false,1,8)
	motion.step(scene)
	check(model.plant(planter.id,1),"real charge planted")
	var key := "1/30"
	var knelt := false
	var carried := false
	var frames_seen := {}
	var covered := false
	for frame in 50*3:
		motion.step(scene)
		var soldier: Dictionary = motion.tracks[planter.id].soldiers[0]
		if soldier.crouch >= 1.0: knelt = true
		if motion.charges.has(key) and not motion.charges[key].placed: carried = true
		if soldier.plant >= 0:
			frames_seen[soldier.plant] = true
			# The fuse counter never covers the kneeling planter (either side of the box).
			var charge: Dictionary = model.charges[0]
			var label := scene.charge_label(charge)
			var foot: Vector2 = motion.point(scene,planter)+Vector2(soldier.face*1.25,0)
			var body := Poses.bounds(foot,soldier.face,Poses.PLANT,soldier.plant,planter.side)
			if scene.label_rect(label.point,label.text,5,label.anchor).intersects(body): covered = true
	check(carried and knelt,"planter carries the box and kneels")
	check(frames_seen.has(0) and frames_seen.has(1) and not covered,"plant sprites kneel then light, label clear of the planter")
	# Facing the other way the counter moves to the other side of the box.
	var there: Dictionary = {"side":1,"slot":30,"fuse":5}
	var anchor_right: float = scene.charge_label(there).anchor
	motion.tracks[planter.id].soldiers[0].task = {"key":"1/30","t":0.0,"arrived":true}
	motion.tracks[planter.id].soldiers[0].plant = 0
	motion.tracks[planter.id].soldiers[0].face = -1.0
	check(anchor_right == 0.0 and scene.charge_label(there).anchor == 1.0,"counter flips to the side away from a planter on its right")
	motion.tracks[planter.id].soldiers[0].plant = -1
	motion.tracks[planter.id].soldiers[0].task = {}
	motion.tracks[planter.id].soldiers[0].face = 0.0
	check(motion.charges.has(key) and motion.charges[key].placed and motion.charges[key].lit,"box set down and fuse lit")
	check(motion.tracks[planter.id].soldiers[0].shift.length() < 0.01,"planter back in his place")
	# A group wiped out in melee falls one man after another.
	var doomed = model.add_actor(0,8,1,3,false,-1,8)
	motion.step(scene)
	model.actors.erase(doomed)
	motion.melee({"kind":"melee","x":40,"y":6})
	var start: int = motion.bodies.size()
	motion.step(scene)
	var falls: Array = motion.bodies.slice(start).filter(func(body): return body.fall)
	var delays := {}
	for body in falls: delays[snappedf(body.delay,0.01)] = true
	check(falls.size() == 3 and delays.size() == 3,"three men fall at three different moments")
	# Infantry deaths are sprite sequences: no rigid tilt, frames advance and the last one lies.
	check(not Rig.pose(0,0,0).has("tilt") and not Rig.new().has_method("dying"),"rig has no rigid-tilt fall")
	for kind in 3:
		var previous_frame := -1
		var monotonic := true
		for step in 101:
			var fall := Motion.death_frame(kind,step/100.0)
			monotonic = monotonic and fall[1] >= previous_frame and fall[0] == (Poses.FALL_FORWARD if kind == 1 else Poses.FALL_BACK)
			previous_frame = fall[1]
		check(monotonic and Motion.death_frame(kind,0.0)[1] == 0 and Motion.death_frame(kind,1.0)[1] == Poses.count(Motion.death_frame(kind,1.0)[0])-1,"fall %d plays every sprite frame in order" % kind)
	# Boarding: a field group entering a roof climbs instead of appearing there.
	var boarder = model.add_actor(0,14,6,2,false,-1,8)
	motion.step(scene)
	boarder.roof = 0
	boarder.x = model.roof_cell(0,14)
	boarder.y = -1
	motion.step(scene)
	var climbing: Dictionary = motion.tracks[boarder.id].soldiers[0]
	check(not climbing.board.is_empty(),"boarding group climbs")
	var low: float = motion.point(scene,boarder).y
	var rungs := {}
	for frame in 50*3:
		motion.step(scene)
		var rider: Dictionary = motion.tracks[boarder.id].soldiers[0]
		if not rider.board.is_empty(): rungs[motion._board_pose(scene,motion.tracks[boarder.id],rider).frame] = true
	check(rungs.has(0) and rungs.has(1) and rungs.has(2) and rungs.has(3) and rungs.has(Motion.MANTLE),"climb cycles four rung frames then mantles (%s)" % [rungs.keys()])
	check(motion.tracks[boarder.id].soldiers[0].board.is_empty() and motion.point(scene,boarder).y < low-10,"climb ends on the roof (%s, %.1f -> %.1f)" % [motion.tracks[boarder.id].soldiers[0].board,low,motion.point(scene,boarder).y])
	if failures.is_empty():
		print("PASS: sprint-then-wait, planted feet, facing, soldiers per strength, melee, staggered sprite deaths, kneeling plant sprites with a clear counter, dynamite set and lit, ladder climb sprites, merge fade, model untouched")
	else:
		for failure in failures: push_error(failure)
	quit()
