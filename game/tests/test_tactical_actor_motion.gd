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

# Rig/sprite switches are hard cuts: at each one record how far the rig's top and
# its feet centroid are from the sprite's, and how far the soldier's point moved
# since the previous frame (logical px).
func track_jump(jumps: Dictionary, last: Dictionary, name: String, motion, scene, track: Dictionary, soldier: Dictionary) -> void:
	var stance: Dictionary = motion.stance_of(scene,track,soldier)
	var at: Vector2 = motion._soldier_point(scene,track,soldier)
	var active: bool = stance.sprite.frame >= 0
	if last.has(name+"/active") and last[name+"/active"] != active:
		var side: int = track.actor.side
		var sprite_top: float = Poses.top(stance.sprite.family,stance.sprite.frame if active else last[name+"/frame"],side)
		jumps[name+"/top"] = maxf(jumps.get(name+"/top",0.0),absf(Rig.top(stance.rig,side)-sprite_top))
		jumps[name+"/feet"] = maxf(jumps.get(name+"/feet",0.0),Rig.support(stance.rig).length())
		jumps[name+"/step"] = maxf(jumps.get(name+"/step",0.0),at.distance_to(last[name]))
		jumps[name+"/count"] = jumps.get(name+"/count",0)+1
	last[name] = at
	last[name+"/active"] = active
	if active: last[name+"/frame"] = stance.sprite.frame

func worst(jumps: Dictionary, name: String) -> float:
	return maxf(jumps.get(name+"/top",INF),maxf(jumps.get(name+"/feet",INF),jumps.get(name+"/step",INF)))

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
	var clashes := 0
	var jumps := {} # worst rig/sprite switch jump per transition, logical px
	var last_at := {}
	for frame in 50*3:
		motion.step(scene)
		var soldier: Dictionary = motion.tracks[planter.id].soldiers[0]
		if soldier.crouch >= 1.0: knelt = true
		if motion.charges.has(key) and not motion.charges[key].placed: carried = true
		if soldier.plant >= 0: frames_seen[soldier.plant] = true
		track_jump(jumps,last_at,"kneel",motion,scene,motion.tracks[planter.id],soldier)
		if not model.charges.is_empty(): clashes += scene.layout_clashes()
	check(carried and knelt,"planter carries the box and kneels")
	check(jumps.get("kneel/count",0) == 2 and worst(jumps,"kneel") <= 1.0,"stand to kneel and back switch within 1px (top %.2f feet %.2f step %.2f)" % [jumps.get("kneel/top",-1.0),jumps.get("kneel/feet",-1.0),jumps.get("kneel/step",-1.0)])
	check(frames_seen.has(0) and frames_seen.has(1) and clashes == 0,"plant sprites kneel then light; counter and count labels clear of soldiers, wagon tags, roof bodies and each other (%d clashes)" % clashes)
	# The counter knows which side its planter kneels, and takes the first free spot of its list, else the least covered.
	var kneeler: Dictionary = motion.tracks[planter.id].soldiers[0]
	kneeler.task = {"key":key,"t":0.0,"arrived":true}
	kneeler.plant = 0
	var faces := []
	for face in [1.0,-1.0]:
		kneeler.face = face
		faces.append(motion.planter_facing(model.charges[0]))
	check(faces == [1.0,-1.0],"counter placement knows which side the planter kneels (%s)" % [faces])
	var blocker := [Rect2(10,40,10,10)]
	var near := {"point":Vector2(12,45),"text":"2","anchor":0.0,"size":4}
	var half := {"point":Vector2(5,45),"text":"2","anchor":0.0,"size":4}
	var clear := {"point":Vector2(100,45),"text":"2","anchor":0.0,"size":4}
	check(scene._free_spot([near,clear],blocker) == clear and scene._free_spot([near,half],blocker) == half,"label takes the first free spot, else the least covered")
	motion.tracks[planter.id].soldiers[0].plant = -1
	motion.tracks[planter.id].soldiers[0].task = {}
	motion.tracks[planter.id].soldiers[0].face = 0.0
	check(motion.charges.has(key) and motion.charges[key].placed and motion.charges[key].lit,"box set down and fuse lit")
	check(motion.tracks[planter.id].soldiers[0].shift.length() < 0.01,"planter back in his place")
	# Crowded box: two big groups stand at the charge; its counter stays within reach and clear of them.
	model.add_actor(0,30,-1,4,false,1,8)
	model.add_actor(0,31,-1,4,false,1,8)
	var crowd := 0
	for frame in 50*2:
		motion.step(scene)
		crowd += scene.layout_clashes()
	check(crowd == 0,"crowded charge: counter within reach, clear of soldiers and labels (%d clashes)" % crowd)
	# A group wiped out in melee falls one man after another.
	var doomed = model.add_actor(0,8,1,3,false,-1,8)
	motion.step(scene)
	var stood := []
	for soldier in motion.tracks[doomed.id].soldiers: stood.append(motion._soldier_point(scene,motion.tracks[doomed.id],soldier))
	model.actors.erase(doomed)
	motion.melee({"kind":"melee","x":40,"y":6})
	var start: int = motion.bodies.size()
	motion.step(scene)
	var falls: Array = motion.bodies.slice(start).filter(func(body): return body.fall)
	# Alive to first fall frame: each body starts where a soldier stood, and the rig's feet centroid is that point.
	var death_jump := 0.0
	for body in falls:
		var first := Motion.death_frame(body.kind,0.0)
		var wounded: Dictionary = motion.body_rig(body)
		death_jump = maxf(death_jump,maxf(absf(Rig.top(wounded,body.side)-Poses.top(first[0],first[1],body.side)),Rig.support(wounded).length()))

		var nearest := INF
		for point in stood: nearest = minf(nearest,point.distance_to(motion._place(scene,body.roof,body.cell,body.offset)))
		death_jump = maxf(death_jump,nearest)
	check(death_jump <= 1.0,"alive to death frame 0 within 1px (%.2f)" % death_jump)
	# A man with comrades ahead falls back, with comrades behind falls forward.
	var pair := {"facing":1.0,"roof":-1,"actor":{"mammoth":false},"soldiers":[]}
	for slot in [0,2]: pair.soldiers.append(motion._soldier(Vector2.ZERO,slot))
	check(motion._fall_kind(pair,pair.soldiers[0],0.5) == 0 and motion._fall_kind(pair,pair.soldiers[1],0.5) == 1,"fall lands clear of comrades")
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
	var column: int = (model.center_offset()+160)/16+6 # a cell under a wagon of the player's train, as the review fixture
	var boarder = model.add_actor(0,column,6,2,false,-1,8)
	motion.step(scene)
	boarder.roof = 0
	boarder.x = model.roof_cell(0,column)
	boarder.y = -1
	motion.step(scene)
	var climbing: Dictionary = motion.tracks[boarder.id].soldiers[0]
	check(not climbing.board.is_empty(),"boarding group climbs")
	var low: float = motion.point(scene,boarder).y
	var rungs := {}
	var climb_jumps := {}
	var last_climb := {}
	var arrival_clashes := 0
	var landing_gap := 0.0
	var landing_samples := 0
	for frame in 50*3:
		motion.step(scene)
		arrival_clashes += scene.layout_clashes()
		var rider: Dictionary = motion.tracks[boarder.id].soldiers[0]
		track_jump(climb_jumps,last_climb,"climb",motion,scene,motion.tracks[boarder.id],rider)
		if not rider.board.is_empty():
			var pose: Dictionary = motion._board_pose(scene,motion.tracks[boarder.id],rider)
			rungs[pose.frame] = true
			if rider.board.t >= rider.board.run+rider.board.climb+rider.board.rise-0.045 and rider.board.wagon >= 0: # last mantle frames: feet on the drawn roof
				var land_x: float = motion._place(scene,0,rider.cell,motion._offset(motion.tracks[boarder.id],rider)).x+rider.board.land
				landing_samples += 1
				landing_gap = maxf(landing_gap,absf(pose.at.y-preload("res://scripts/tactical_effects_geometry.gd").drawn_y(scene,0,rider.board.wagon,land_x)))
	check(climb_jumps.get("climb/count",0) == 2 and worst(climb_jumps,"climb") <= 1.0,"run, climb, mantle and stand switch within 1px (top %.2f feet %.2f step %.2f)" % [climb_jumps.get("climb/top",-1.0),climb_jumps.get("climb/feet",-1.0),climb_jumps.get("climb/step",-1.0)])
	check(landing_samples > 0 and landing_gap < 0.01,"mantle lands exactly on the drawn roof silhouette (%.3f px)" % landing_gap)
	check(arrival_clashes == 0,"labels clear of soldiers, wagon bodies and each other through the roof arrival (%d clashes)" % arrival_clashes)
	check(rungs.has(0) and rungs.has(1) and rungs.has(2) and rungs.has(3) and rungs.has(Motion.MANTLE),"climb cycles four rung frames then mantles (%s)" % [rungs.keys()])
	check(motion.tracks[boarder.id].soldiers[0].board.is_empty() and motion.point(scene,boarder).y < low-10,"climb ends on the roof (%s, %.1f -> %.1f)" % [motion.tracks[boarder.id].soldiers[0].board,low,motion.point(scene,boarder).y])
	if failures.is_empty():
		print("switch mismatch, logical px (top/feet/step): kneel %.2f/%.2f/%.2f, climb %.2f/%.2f/%.2f, death %.2f" % [jumps.get("kneel/top",-1.0),jumps.get("kneel/feet",-1.0),jumps.get("kneel/step",-1.0),climb_jumps.get("climb/top",-1.0),climb_jumps.get("climb/feet",-1.0),climb_jumps.get("climb/step",-1.0),death_jump])
		print("PASS: sprint-then-wait, planted feet, facing, soldiers per strength, melee, staggered sprite deaths, kneeling plant sprites with a clear counter, dynamite set and lit, ladder climb sprites, merge fade, model untouched")
	else:
		for failure in failures: push_error(failure)
	quit()
