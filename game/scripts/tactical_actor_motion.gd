extends RefCounted
# MIT. Presentation of tactical groups, keyed by actor id: each group shows up
# to four soldiers who sprint to the new source cell, brake onto it and wait
# for the next step; planted feet never slide (stride phase follows distance).
# Melee: strikes and recoils; every man lost falls, one after another, in one
# of three falls. Dynamite: the planter runs to the slot, kneels, sets the box
# and lights the fuse. Boarding: run to the wagon, climb its side, mantle.
# Reads the combat model only, on the shared50Hz visual step; presentation
# RNG is separate from the source. Authored presentation: the original draws
# field actors as map tiles (WDECOR cputmap98) and roof actors as sprites
# 10+cell (0x5126); its facing and in-between motion are not decoded, so none
# of this claims original behaviour.
const Geometry = preload("res://scripts/tactical_effects_geometry.gd")
const Rig = preload("res://scripts/tactical_trooper_rig.gd")
const Poses = preload("res://scripts/tactical_trooper_poses.gd")
const Mammoth = preload("res://scripts/tactical_mammoth_poses.gd")
const Beast = preload("res://scripts/tactical_mammoth_motion.gd")
const STEP := 1.0/50.0
const SPRINT := 22.0 # source: authored top speed, logical px/s (~1.7 body heights/s).
const ACCEL := 140.0 # source: authored, logical px/s².
const BRAKE := 110.0 # source: authored, logical px/s².
const CLIMB := 24.0 # source: authored climbing speed up a wagon side, logical px/s.
const RUNG := 3.0 # source: authored climbing step, logical px.
const MANTLE := 4 # index of the mantle among the climb frames, after the four rung frames.
const BOX_HALF := 1.75 # half the drawn box's width, logical px (see _draw_box).
const LADDER_GRAB := 1.5 # source: authored; the rails stand this far above the roof, a grab handle.
const KNEEL_CROUCH := 1.0 # source: measured on the rig; beyond ~1.2 its feet sink below the ground line and the coat bunches.
const HULL_DROP := 4.0 # source: measured on the wagon sprites; the cap falls ~10px at the hull end, the roof's own curve under 3.
const MANTLE_START := 8.8 # source: Poses.hand(4): the mantle's fist is this high above its feet, logical px.
const MANTLE_SINK := 0.6 # source: authored; the rear foot ends this far under the roof surface, the rig then stands on it.
const MANTLE_SWING := 1.5 # source: authored; the hull-ward move finishes this much sooner than the haul.
const LAND := 4.0 # source: authored; the mantle lands this far inside the ladder, on the flat roof (the roof's end drops away at the ladder).
const FALL_REACH := 14.0 # source: measured, logical px; length of a lying soldier (Poses fall frames, 12-14).
const SETTLE := 0.12 # source: authored; the runner gathers his feet this long before the ladder, s.
const MANTLE_HOLD := 0.6 # source: authored share of the rise spent in the mantle sprite before standing.
const WAGON_SIDE := 25.0 # source: roof 38 above the top train baseline 63, logical px.
const MAMMOTH_SPEED := 14.0 # source: authored heavy gait, logical px/s.
const STRIDE_PX := Rig.STRIDE/Rig.PER # one step of the rig, logical px.
# Riders stepping off a howdah (0x123a): seconds on each of the 5 dismount frames (stand on the
# rim, leg over, hang from it, drop, land). They climb down the howdah's rear end, behind the
# rump, where the sprite shows him clear of the flank; HANG_OUT logical px outside the rim end (authored).
const DISMOUNT := [0.25,0.22,0.3,0.14,0.22]
const HANG_OUT := 2.0
const REAR := 3.0 # source: authored, logical px a toppling rider starts behind his seat, over the howdah's rear rim.
const DISMOUNT_GAP := 0.5 # source: authored, s between two riders stepping off the same howdah.
const VISIBLE := 4 # source: authored most soldiers drawn per group.
# Formation offsets, logical px; negative y stands farther from the viewer.
const FIELD_FORMATION := [Vector2(1,0),Vector2(-6,-3),Vector2(6.5,-1.5),Vector2(-0.5,-5.5)]
const ROOF_FORMATION := [Vector2(0,0),Vector2(-4.5,0),Vector2(4.5,0),Vector2(-2,0)]
const STRIKE := 0.35 # source: authored blow duration, s.
const RECOIL := 0.35 # source: authored hit reaction, s.
const ENGAGED := 1.2 # source: authored hold-facing after a melee, s.
const NEXT_FALL := 0.3 # source: authored delay between successive deaths, s.
const LIE := 3.0 # source: authored time a casualty stays down, s.
const FADE := 0.6 # source: authored fade of bodies and merged groups, s.
# Deaths play the sprite falls of Poses over DEATH s (kind 1 pitches forward,
# the others are thrown back), the last frame landing at IMPACT.
const DEATH := 0.9 # source: authored fall duration, s.
const IMPACT := 0.85 # source: authored fraction of DEATH when the body lands.
# Plant sequence, s (authored): kneel, set the box, light the fuse, rise.
const KNEEL := 0.25
const SET := 0.35
const LIGHT := 0.35
const RISE := 0.25
var tracks := {}
var bodies := []
var charges := {} # "side/slot" → {"placed","lit"}
var _melees := []
var _rng := RandomNumberGenerator.new()
var _sparks := 0


func _init() -> void:
	clear()


func clear() -> void:
	tracks.clear()
	bodies.clear()
	charges.clear()
	_melees.clear()
	_rng.seed = 7 # source: authored fixed presentation seed, independent of the model RNG.


func melee(event: Dictionary) -> void:
	_melees.append(event)


func step(scene) -> void:
	var state = scene.state
	var fighting := not _melees.is_empty()
	var seen := {}
	for track in tracks.values(): track.shed = 0
	for actor in state.actors:
		seen[actor.id] = true
		var cell := Vector2(actor.x,actor.y)
		var fresh := not tracks.has(actor.id)
		var track := _track(actor)
		if fresh and actor.roof >= 0: _board_from_shedder(scene,track)
		if actor.roof != track.roof:
			if track.roof < 0 and actor.roof >= 0: _board(scene,track,cell)
			else: _snap(track,cell)
		elif track.to.distance_to(cell) > 1.5:
			_snap(track,cell) # restore, split/merge: unrelated positions snap
		elif cell != track.to:
			var dx: float = (cell.x-track.to.x)*(-1.0 if actor.roof >= 0 else 1.0) # roof slots run right→left
			if absf(dx) > 0.01 and track.engaged <= 0: track.facing = signf(dx)
			track.to = cell
			for index in track.soldiers.size():
				track.soldiers[index].delay = index*0.06+_rng.randf()*0.05 # source: authored ragged start.
		_muster(track,actor,fighting)
		track.count = actor.count
		for soldier in track.soldiers: _run(track,soldier)
		track.engaged = maxf(0.0,track.engaged-STEP)
	for id in tracks.keys():
		if seen.has(id): continue
		var track: Dictionary = tracks[id]
		var order := 0
		for soldier in track.soldiers:
			_drop(track,soldier,fighting,order*NEXT_FALL+_rng.randf()*0.12)
			order += 1
		tracks.erase(id)
	for event in _melees: _engage(event)
	_melees.clear()
	_plants(state)
	_age_bodies(scene)


func _track(actor: Dictionary) -> Dictionary:
	if not tracks.has(actor.id):
		var cell := Vector2(actor.x,actor.y)
		tracks[actor.id] = {"to":cell,"roof":actor.roof,"facing":1.0,"count":actor.count,"engaged":0.0,"shed":0,"soldiers":[],"leaving":[],"dying":[],"actor":actor}
		_muster(tracks[actor.id],actor,false)
	var track: Dictionary = tracks[actor.id]
	track.actor = actor
	return track


func _snap(track: Dictionary, cell: Vector2) -> void:
	track.roof = track.actor.roof
	track.to = cell
	for soldier in track.soldiers:
		soldier.cell = cell
		soldier.speed = 0.0
		soldier.board = {}
		soldier.walk = {}
		soldier.gait = -1
		soldier.lag = Vector2.ZERO


# Visible soldiers follow the group's strength. In a melee every loss fells a
# visible man, at most two per report, one after the other; when the group is
# still larger than what is drawn, a comrade runs in to fill the gap.
func _muster(track: Dictionary, actor: Dictionary, fighting: bool) -> void:
	var wanted := 1 if actor.mammoth else clampi(actor.count,1,VISIBLE)
	var losses: int = track.count-actor.count
	if actor.mammoth and fighting and losses > 0: _drop_riders(track,Mammoth.riders(track.count),Mammoth.riders(actor.count))
	if losses > 0 and not fighting and actor.roof < 0: track.shed += losses # men leaving to board
	var falls := mini(losses,2) if fighting and not actor.mammoth else 0
	var order := 0
	while track.soldiers.size() > wanted:
		var leaving: Dictionary = track.soldiers.pop_back()
		if fighting: _drop(track,leaving,true,order*NEXT_FALL)
		elif track.shed == 0: _drop(track,leaving,false,0.0) # merged away: fades
		order += 1
	while order < falls and track.soldiers.size() > 1: # replaced at once by a comrade
		var index: int = 1+_rng.randi()%(track.soldiers.size()-1)
		var victim: Dictionary = track.soldiers[index]
		_drop(track,victim,true,order*NEXT_FALL)
		var comrade := _soldier(victim.cell,victim.slot)
		comrade.shift = Vector2(-track.facing*10.0,-1.5) # source: authored, steps in from behind.
		comrade.delay = order*NEXT_FALL+0.3
		track.soldiers[index] = comrade
		order += 1
	if fighting and losses > 0 and not track.soldiers.is_empty(): _hit(track.soldiers[0],actor.mammoth,1.0)
	while track.soldiers.size() < wanted:
		track.soldiers.append(_soldier(track.to,track.soldiers.size()))


# Riders killed in the howdah while the beast lives: the spotter (rear) goes first, then the gunner;
# each slumps, topples off the rim and lies (rider_fall), one after the other.
func _drop_riders(track: Dictionary, before: int, after: int) -> void:
	if after >= before or track.soldiers.is_empty(): return
	var lost := [1] if after == 0 and before == 1 else ([0] if after == 1 else [0,1]) # both: one pair sprite, as the beast's death
	var pair: bool = lost.size() > 1
	var soldier: Dictionary = track.soldiers[0]
	var order := 0
	for which in ([0] if pair else lost):
		bodies.append({"roof":track.roof,"cell":soldier.cell-soldier.lag,"offset":_offset(track,soldier)+soldier.shift,
			"facing":soldier.face if soldier.face != 0 else track.facing,"side":track.actor.side,"mammoth":false,"rider":which,
			"pair":pair,"count":0,"t":0.0,"delay":order*NEXT_FALL,"fall":true,"landed":true,"kind":0,"breath":0.0,
			"span":Beast.rider_fall_time(_launch(track.actor.side,Mammoth.STOP,0,which))})
		track.dying.append(bodies[-1])
		order += 1
	track.dying = track.dying.filter(func(body): return body.t < body.delay+body.span)


# The rim point a rider topples from, logical px from the beast's pivot (x toward the facing).
func _launch(side: int, motion: int, index: int, which: int) -> Vector2:
	var rim := Mammoth.rim_point(side,motion,index)
	return Vector2(rim.x+Mammoth.seat_x(side,which)-REAR,rim.y)


func _soldier(cell: Vector2, slot: int) -> Dictionary:
	return {"cell":cell,"speed":0.0,"amp":0.0,"phase":_rng.randf()*TAU,"delay":0.0,
		"vmul":_rng.randf_range(0.92,1.08),"breath":_rng.randf()*TAU,"strike":0.0,"recoil":0.0,
		"slot":slot%VISIBLE,"offset":Vector2.ZERO,"shift":Vector2.ZERO,"shift_to":Vector2.ZERO,
		"shift_speed":0.0,"face":0.0,"board":{},"task":{},"crouch":0.0,"plant":-1,
		"walk":{},"gait":-1,"halt":0.0,"lag":Vector2.ZERO,"strike_len":STRIKE,"recoil_len":RECOIL}


func _drop(track: Dictionary, soldier: Dictionary, fell: bool, delay: float) -> void:
	var actor: Dictionary = track.actor
	var roll := _rng.randf()
	# A mammoth that leaves the field is dead (it never merges away) and falls whatever the cause.
	bodies.append({"roof":track.roof,"cell":soldier.cell-soldier.lag,"offset":_offset(track,soldier)+soldier.shift,
		"facing":soldier.face if soldier.face != 0 else track.facing,"side":actor.side,"mammoth":actor.mammoth,
		"count":actor.count,"t":0.0,"delay":delay,"fall":fell or actor.mammoth,"span":Beast.DEATH if actor.mammoth else DEATH,
		"kind":_fall_kind(track,soldier,roll),"landed":false,"breath":soldier.breath})


# Falls toward the side with fewer comrades standing within a body length, so
# the faller lands clear of them; with no difference the roll chooses.
func _fall_kind(track: Dictionary, soldier: Dictionary, roll: float) -> int:
	var kind := 0 if roll < 0.4 else (1 if roll < 0.75 else 2)
	var mine: Vector2 = _offset(track,soldier)+soldier.shift
	var ahead := 0
	var behind := 0
	for other in track.soldiers:
		if other == soldier: continue
		var dx: float = (_offset(track,other)+other.shift-mine).x*(soldier.face if soldier.face != 0 else track.facing)
		if absf(dx) > FALL_REACH: continue
		if dx > 0: ahead += 1
		else: behind += 1
	if ahead > behind: return 0 if kind != 2 else 2 # backward falls
	if behind > ahead: return 1 # forward falls
	return kind


func _age_bodies(scene) -> void:
	for body in bodies:
		body.t += STEP
		if body.fall and not body.landed and (body.t-body.delay)/body.span >= IMPACT:
			body.landed = true # snow kicked up where the body hits
			var lying := death_frame(body.kind,1.0)
			var reach: float = -body.facing*2.0 if body.mammoth else body.facing*Poses.centre(lying[0],lying[1])
			var at := _place(scene,body.roof,body.cell,body.offset)+Vector2(reach,0) # where the body lies
			scene.living.add("dust",at+Vector2(scene.camera,0),Vector2.UP,0.12) # source: authored light puff
	bodies = bodies.filter(func(body): return body.t < (body.delay+body.span+LIE+FADE if body.fall else FADE))


# Sprint kinematics: accelerate, hold top speed, brake to stop on the cell.
func _run(track: Dictionary, soldier: Dictionary) -> void:
	var mammoth: bool = track.actor.mammoth
	var actor_side: int = track.actor.side
	soldier.strike = maxf(0.0,soldier.strike-STEP)
	soldier.recoil = maxf(0.0,soldier.recoil-STEP)
	soldier.breath += STEP*2.4 # source: authored breathing rate, rad/s.
	var stride := STRIDE_PX
	if not soldier.board.is_empty():
		_climbing(soldier)
		return
	_task(soldier,actor_side)
	var travelled := 0.0
	var remaining: float = soldier.cell.distance_to(track.to)*16.0
	if soldier.delay > 0:
		soldier.delay -= STEP
	elif remaining > 0.001:
		var top: float = (MAMMOTH_SPEED if mammoth else SPRINT)*soldier.vmul
		var wanted := minf(top,sqrt(2.0*BRAKE*remaining))
		soldier.speed = move_toward(soldier.speed,wanted,(ACCEL if wanted > soldier.speed else BRAKE*1.5)*STEP)
		var move := minf(maxf(soldier.speed,4.0)*STEP,remaining) # source: authored 4px/s creep to settle.
		soldier.cell = soldier.cell.move_toward(track.to,move/16.0)
		travelled += move
		if soldier.cell.distance_to(track.to)*16.0 < 0.01: soldier.cell = track.to
	else:
		soldier.speed = 0.0
	# Individual runs inside the formation (comrade stepping in, planter).
	var gap: float = soldier.shift.distance_to(soldier.shift_to)
	if gap > 0.001 and soldier.delay <= 0:
		var wanted_shift := minf(SPRINT*0.9,sqrt(2.0*BRAKE*gap))
		soldier.shift_speed = move_toward(soldier.shift_speed,wanted_shift,ACCEL*STEP)
		var move := minf(maxf(soldier.shift_speed,4.0)*STEP,gap)
		soldier.shift = soldier.shift.move_toward(soldier.shift_to,move)
		travelled += move
	else:
		soldier.shift_speed = 0.0
	soldier.phase += travelled/stride*PI
	# Full stride as soon as the body travels; feet gather while it stops.
	soldier.amp = move_toward(soldier.amp,clampf(maxf(soldier.speed,soldier.shift_speed)/6.0,0,1),STEP*6.0)
	if mammoth: Beast.gait(track,soldier)


func _swing(soldier: Dictionary, mammoth: bool) -> void:
	soldier.strike_len = Beast.STRIKE if mammoth else STRIKE
	soldier.strike = soldier.strike_len


func _hit(soldier: Dictionary, mammoth: bool, share: float) -> void:
	soldier.recoil_len = (Beast.RECOIL if mammoth else RECOIL)*share
	soldier.recoil = soldier.recoil_len


# Dynamite: run to the charge, kneel, set the box, light the fuse, rise, return.
func _task(soldier: Dictionary, side: int) -> void:
	var task: Dictionary = soldier.task
	soldier.crouch = 0.0
	soldier.plant = -1
	if task.is_empty(): return
	task.t += STEP
	if not task.arrived:
		if soldier.shift.distance_to(soldier.shift_to) < 0.05 or task.t > 1.2:
			task.arrived = true
			task.t = 0.0
		return
	var t: float = task.t
	var entry: Dictionary = charges.get(task.key,{})
	# The rig crouches down to the kneel pose whose height matches the sprite's,
	# the sprite takes over for the set and the light, and the rig rises from that
	# same crouch (hard switches at equal height and feet, no blending).
	var done := KNEEL+SET+LIGHT
	var kneel := minf(_matched(side,Poses.top(Poses.PLANT,0,side)),KNEEL_CROUCH)
	if t >= KNEEL and t < done: soldier.plant = 0 if t < KNEEL+SET else 1
	if t < KNEEL: soldier.crouch = kneel*t/KNEEL
	elif t < done: soldier.crouch = kneel
	elif t < done+RISE: soldier.crouch = kneel*(1.0-(t-done)/RISE)
	if not entry.is_empty():
		entry.placed = entry.placed or t >= KNEEL+SET*0.7
		entry.lit = entry.lit or t >= KNEEL+SET+LIGHT*0.6
	if t >= KNEEL+SET+LIGHT+RISE:
		soldier.shift_to = Vector2.ZERO # back to his place in the group
		soldier.face = 0.0
		soldier.task = {}


# Boarding: run to the foot of the wagon, climb its side, mantle onto the roof.
func _board(scene, track: Dictionary, cell: Vector2) -> void:
	var froms := []
	for soldier in track.soldiers:
		froms.append({"cell":soldier.cell,"offset":_offset(track,soldier)+soldier.shift})
	_snap(track,cell)
	for index in track.soldiers.size():
		_start_climb(scene,track,track.soldiers[index],froms[index].cell,froms[index].offset,index*0.12)


# 0x123a: riders and infantry crossing to the player's roof leave a field
# group of the same side; the new roof group climbs from that group's place.
func _board_from_shedder(scene, track: Dictionary) -> void:
	var actor: Dictionary = track.actor
	var here := _place(scene,actor.roof,track.to,Vector2.ZERO).x
	var source = null
	var best := INF
	for other in tracks.values():
		if other == track or other.shed <= 0 or other.roof >= 0 or other.actor.side != actor.side: continue
		var distance := absf(_place(scene,-1,other.to,Vector2.ZERO).x-here)
		if distance < best:
			best = distance
			source = other
	if source == null: return
	var start: Vector2 = source.soldiers[0].cell if not source.soldiers.is_empty() else source.to
	if not source.actor.mammoth:
		for index in track.soldiers.size(): _start_climb(scene,track,track.soldiers[index],start,FIELD_FORMATION[index%VISIBLE],index*0.12)
		return
	# Riders step off the howdah one after the other: stand on its rim, swing a leg over, hang, drop, land
	# beside the beast, then run to the wagon; until each one's turn the howdah's rider layer shows him.
	var beast := _beast_point(scene,source)
	var offset: Vector2 = beast-scene._field_point(start.x,start.y)
	for index in track.soldiers.size():
		var soldier: Dictionary = track.soldiers[index]
		_start_climb(scene,track,soldier,start,offset,index*DISMOUNT_GAP,{"source":source,"which":index%Mammoth.SEATED})
		source.leaving.append(soldier)


# Climbs go up the end ladder of the wagon nearest the runner (ladders drawn
# 3px inside each wagon end), then he runs along the roof to his slot.
# ride: {source, which} when he steps off a howdah first (dismount frames, then he runs from where he lands).
func _start_climb(scene, track: Dictionary, soldier: Dictionary, from_cell: Vector2, from_offset: Vector2, delay: float, ride := {}) -> void:
	var start := _place(scene,-1,from_cell,from_offset)
	var top := _place(scene,track.roof,soldier.cell,_offset(track,soldier))
	var height := minf(start.y-top.y,WAGON_SIDE)
	var climbing := height > 6.0
	if not climbing: height = start.y-top.y
	var ladder := 0.0 # screen offset, from his slot, of the wagon's end edge where he climbs
	var out := 1.0 # which way is out from that edge: +1 right
	var index := Geometry.wagon_at(scene,track.roof,top.x)
	if climbing and index >= 0:
		var rect: Rect2 = Geometry.wagon(scene,track.roof,index).rect
		var left := _hull_end(scene,track.roof,index,-1.0)
		var right := _hull_end(scene,track.roof,index,1.0)
		ladder = (left if absf(left-top.x) < absf(right-top.x) else right)-top.x
		if absf(ladder) > 32.0: ladder = 0.0 # source: half a 64px wagon; longer bodies climb in place
		else: out = 1.0 if top.x+ladder > rect.get_center().x else -1.0
	var wagon: int = index if ladder != 0.0 else -1
	var land := ladder-out*LAND # screen offset, from his slot, of where the mantle puts his feet
	var roof := Vector2(top.x+land,_roof_y(scene,track.roof,wagon,top.x+land,top.y))
	var cap := _roof_y(scene,track.roof,wagon,top.x+ladder,top.y) # the roof's end cap at the ladder
	var foot := Vector2(top.x+ladder+out*Poses.hand(0).x,roof.y+height)
	# He climbs from the ground to the top rung, where his feet are when the mantle starts and his
	# hand is on the roof edge. Rungs are evenly spaced and their count is 2 mod 4, so the last
	# rung frame is always the one that reaches the edge (frame 1).
	var climbed := maxf(foot.y-(cap+MANTLE_START),RUNG*2)
	var rungs := 4*maxi(0,roundi((climbed/RUNG-2.0)/4.0))+2
	var heading := signf(foot.x-start.x) if absf(foot.x-start.x) > 0.5 else 0.0
	var dismount := 0.0
	var drop := Vector2.ZERO # where he lands from the beast's point
	if not ride.is_empty():
		var seat := Mammoth.seat(ride.source.actor.side,ride.which)
		drop = Vector2((Mammoth.rim(ride.source.actor.side).x-HANG_OUT)*ride.source.facing,0) # behind the rump
		from_offset += drop
		start += drop
		for time in DISMOUNT: dismount += time
	soldier.board = {"from_cell":from_cell,"from_offset":from_offset,"t":-delay,"height":height,"ladder":ladder,"out":out,"land":land,"wagon":wagon,"rungs":rungs,"rung":climbed/rungs,
		"run":start.distance_to(foot)/SPRINT,"climb":climbed/CLIMB if climbing else 0.35,"hop":not climbing,"rise":0.45,
		"dismount":dismount,"source":ride.get("source",{}),"which":ride.get("which",0),"face":heading}
	soldier.face = heading


func _climbing(soldier: Dictionary) -> void:
	var board: Dictionary = soldier.board
	board.t += STEP
	var t: float = board.t-board.dismount
	if board.t < 0: return
	if t < 0: # stepping off the howdah: the dismount frames play
		soldier.amp = 0.0
		return
	if t < board.run: # running to the wagon, feet gathering for the last SETTLE s
		soldier.phase += SPRINT*STEP/STRIDE_PX*PI
		soldier.amp = move_toward(soldier.amp,1.0 if t < board.run-SETTLE else 0.0,STEP*8.0)
	elif t < board.run+board.climb: # rung over rung up the end ladder, facing the wagon
		if not board.hop: soldier.phase += CLIMB*STEP/RUNG*PI
		soldier.amp = 0.0
		if board.wagon >= 0: soldier.face = -board.out # toward the wagon
	else:
		soldier.amp = move_toward(soldier.amp,0.0,STEP*6.0)
	if t >= board.run+board.climb+board.rise:
		soldier.shift = Vector2(board.land,0) # then along the roof to his slot
		soldier.shift_to = Vector2.ZERO
		soldier.board = {}
		soldier.face = 0.0


# Where a boarding soldier is and how he is drawn: "frame" is the climb sprite
# (-1: rig) and "amp" the rig layer's stride (-1: his own).
func _board_pose(scene, track: Dictionary, soldier: Dictionary) -> Dictionary:
	var board: Dictionary = soldier.board
	var start := _place(scene,-1,board.from_cell,board.from_offset)
	var top := _place(scene,track.roof,soldier.cell,_offset(track,soldier))
	var edge_x: float = top.x+board.ladder
	var land_x: float = top.x+board.land
	var out: float = board.out
	var roof := Vector2(land_x,_roof_y(scene,track.roof,board.wagon,land_x,top.y))
	var cap := _roof_y(scene,track.roof,board.wagon,edge_x,top.y) # the roof's end cap at the ladder
	var foot := Vector2(edge_x+out*Poses.hand(0).x,roof.y+board.height)
	var pose := {"at":foot,"climb":0.0,"crouch":0.0,"frame":-1,"amp":-1.0,"dismount":-1}
	if board.t < board.dismount: return _dismount_pose(scene,board,pose)
	var t: float = maxf(board.t-board.dismount,0.0)
	if t < board.run:
		pose.at = start.lerp(foot,t/maxf(board.run,0.001))
		return pose
	if t < board.run+board.climb+STEP*0.5:
		var u: float = clampf((t-board.run)/board.climb,0,1)
		if board.hop: # vault: crouch, jump, land
			pose.at = foot.lerp(roof,u)+Vector2(0,-6.0*sin(PI*u))
			pose.crouch = 0.5*(1.0-sin(PI*u))
			return pose
		# One rung frame per rung climbed, his hand on the rail at the hull end the whole way.
		var frame := mini(int(u*board.rungs),board.rungs-1)%MANTLE
		pose.at = Vector2(edge_x+out*Poses.hand(frame).x,lerpf(foot.y,cap+MANTLE_START,u))
		pose.frame = frame
		return pose
	var rise: float = clampf((t-board.run-board.climb)/board.rise,0,1)
	if board.hop:
		pose.at = roof
		pose.crouch = 1.0-rise
		return pose
	# Mantle: the fist on the roof edge, he hauls himself up alongside the hull end and in
	# onto the roof (the rear foot arrives last), then stands up as the rig.
	var pull := clampf(rise/MANTLE_HOLD,0,1)
	var from := Vector2(edge_x+out*Poses.hand(MANTLE).x,cap+MANTLE_START)
	var to := Vector2(roof.x,roof.y+MANTLE_SINK) # rear foot just under the roof surface at the landing point, front knee up
	pose.at = Vector2(lerpf(from.x,to.x,smoothstep(0,1,minf(pull*MANTLE_SWING,1.0))),lerpf(from.y,to.y,smoothstep(0,1,pull)))
	if rise >= MANTLE_HOLD: pose.at = roof
	if rise < MANTLE_HOLD: pose.frame = MANTLE
	pose.crouch = _matched(track.actor.side,Poses.top(Poses.CLIMB,MANTLE,track.actor.side))*(1.0-clampf((rise-MANTLE_HOLD)/(1.0-MANTLE_HOLD),0,1))
	pose.amp = 0.0
	return pose


# Where a mammoth group stands (its drawn feet), or its target cell once it is gone.
func _beast_point(scene, source: Dictionary) -> Vector2:
	if source.soldiers.is_empty(): return _place(scene,-1,source.to,Vector2.ZERO)
	return _soldier_point(scene,source,source.soldiers[0])


# A rider stepping off a howdah: which dismount frame, and where his feet are. Frames 0-1 stand
# on the howdah's rim at his seat (following the beast), 2 hangs from the rim, 3 drops, 4 lands
# where the run to the wagon starts.
func _dismount_pose(scene, board: Dictionary, pose: Dictionary) -> Dictionary:
	var source: Dictionary = board.source
	var side: int = source.actor.side
	var beast := _beast_point(scene,source)
	var seat := Mammoth.seat(side,board.which)
	var rim := beast+Vector2(seat.x*source.facing,seat.y)
	var edge := beast+Vector2((Mammoth.rim(side).x-HANG_OUT)*source.facing,Mammoth.rim(side).y) # outside the rear end of the rim
	var landing := _place(scene,-1,board.from_cell,board.from_offset)
	var hang := edge+Vector2(0,Mammoth.dismount_height(side,2)-0.5)
	var t := maxf(board.t,0.0)
	var k := 0
	for time in DISMOUNT:
		if t < time or k == DISMOUNT.size()-1: break
		t -= time
		k += 1
	var u := clampf(t/DISMOUNT[k],0,1)
	pose.dismount = k
	if k == 0: pose.at = rim
	elif k == 1: pose.at = rim.lerp(edge,u) # along the rim to its rear end
	elif k == 2: pose.at = hang
	elif k == 3: pose.at = hang.lerp(landing,u*u) # falls, speeding up
	else: pose.at = landing
	return pose


# x of a wagon's hull end on one side (out: +1 right, -1 left): the outermost
# column whose drawn roof is still within HULL_DROP of the roof 9px inside, where
# the end cap falls away and the coupler platform begins.
func _hull_end(scene, roof: int, index: int, out: float) -> float:
	var rect: Rect2 = Geometry.wagon(scene,roof,index).rect
	var edge := rect.end.x if out > 0 else rect.position.x
	var flat := Geometry.drawn_y(scene,roof,index,edge-out*9.0)
	var x := edge
	while absf(x-edge) < 9.0 and Geometry.drawn_y(scene,roof,index,x) > flat+HULL_DROP: x -= out*0.25
	return x


# Roof surface under x of the wagon being climbed (clamped to it); fallback outside any wagon.
func _roof_y(scene, roof: int, index: int, x: float, fallback: float) -> float:
	if index < 0: return fallback
	var rect: Rect2 = Geometry.wagon(scene,roof,index).rect
	return Geometry.drawn_y(scene,roof,index,clampf(x,rect.position.x,rect.end.x))


# WDECOR0x2679 melee reports the attacker's cell; both groups turn to fight.
func _engage(event: Dictionary) -> void:
	var attacker = null
	for track in tracks.values():
		if track.actor.x == event.x and track.actor.y == event.y: attacker = track
	if attacker == null or attacker.soldiers.is_empty(): return
	var target = null
	for track in tracks.values():
		if track.actor.side == attacker.actor.side or track.roof != attacker.roof: continue
		if target == null or track.to.distance_to(attacker.to) < target.to.distance_to(attacker.to): target = track
	if target == null: return
	var dx: float = (target.to.x-attacker.to.x)*(-1.0 if attacker.roof >= 0 else 1.0)
	if absf(dx) > 0.01:
		attacker.facing = signf(dx)
		target.facing = -signf(dx)
	attacker.engaged = ENGAGED
	target.engaged = ENGAGED
	# One soldier swings per report; the struck group's front man reels.
	var striker: Dictionary = attacker.soldiers[_rng.randi()%attacker.soldiers.size()]
	_swing(striker,attacker.actor.mammoth)
	if not target.soldiers.is_empty() and target.soldiers[0].recoil <= 0: _hit(target.soldiers[0],target.actor.mammoth,0.6)


# A new charge (0x1c73 enemy, 0x4674 player) sends the planting group's
# nearest soldier to set it; charges with no planter in view are shown lit.
func _plants(state) -> void:
	var current := {}
	for charge in state.charges:
		var key := "%d/%d" % [charge.side,charge.slot]
		if charges.has(key):
			current[key] = charges[key]
			continue
		current[key] = {"placed":true,"lit":true}
		var planter = null
		for track in tracks.values():
			var actor: Dictionary = track.actor
			if actor.side != charge.owner or actor.roof != charge.side or track.soldiers.is_empty(): continue
			if absi(actor.x-charge.slot) <= 2 and (planter == null or absi(actor.x-charge.slot) < absi(planter.actor.x-charge.slot)):
				planter = track
		if planter == null: continue
		var soldier: Dictionary = planter.soldiers[0]
		var screen: float = -(charge.slot-soldier.cell.x)*16.0 # roof slots run right→left
		var side := signf(screen) if screen != 0 else float(planter.facing)
		soldier.shift_to = Vector2(screen-_offset(planter,soldier).x-side*(BOX_HALF+Poses.BOX_REACH[0]),0) # feet where the kneeling sprite's box edge meets the drawn box.
		soldier.face = side
		soldier.task = {"key":key,"t":0.0,"arrived":false}
		current[key] = {"placed":false,"lit":false}
	charges = current


# Facing of the soldier kneeling at a charge (+1: he stands left of it), 0 if none.
func planter_facing(charge: Dictionary) -> float:
	var key := "%d/%d" % [charge.side,charge.slot]
	for track in tracks.values():
		for soldier in track.soldiers:
			if soldier.plant >= 0 and soldier.task.get("key","") == key: return soldier.face
	return 0.0


# A group whose men are all still stepping off a howdah has no label yet: they belong to the
# beast until they have landed, then become a group of their own.
func label_hidden(actor: Dictionary) -> bool:
	var track: Dictionary = tracks.get(actor.id,{})
	if track.is_empty() or track.soldiers.is_empty(): return false
	for soldier in track.soldiers:
		if soldier.board.is_empty() or soldier.board.dismount <= 0.0 or soldier.board.t >= soldier.board.dismount: return false
	return true


# Logical-px rectangles of the soldiers standing or kneeling on screen (for label placement).
func soldier_rects(scene) -> Array:
	var rects := []
	for track in tracks.values():
		for soldier in track.soldiers:
			if not soldier.board.is_empty() and soldier.board.t < 0: continue # still seated: drawn with the howdah
			var at := _soldier_point(scene,track,soldier)
			if track.actor.mammoth:
				var state := Beast.state(track,soldier)
				rects.append(Mammoth.bounds(track.actor.side,state.kind,state.motion,state.index,at,track.facing,state.riders))
				continue
			var facing: float = soldier.face if soldier.face != 0 else track.facing
			if soldier.board.is_empty() and soldier.plant >= 0: rects.append(Poses.bounds(at,facing,Poses.PLANT,soldier.plant,track.actor.side))
			else: rects.append(Rect2(at+Vector2(-4,-13),Vector2(8,12))) # source: standing rig, 13 px tall, ~8 wide with its rifle; boots may meet a label below.
	return rects


func _offset(track: Dictionary, soldier: Dictionary) -> Vector2:
	if soldier.offset != Vector2.ZERO or track.actor.mammoth: return soldier.offset
	return (ROOF_FORMATION if track.roof >= 0 else FIELD_FORMATION)[soldier.slot]


func _place(scene, roof: int, cell: Vector2, offset: Vector2) -> Vector2:
	if roof >= 0: return Geometry.roof_point_at(scene,roof,cell.x-offset.x/16.0)
	return scene._field_point(cell.x,cell.y)+offset


func _soldier_point(scene, track: Dictionary, soldier: Dictionary) -> Vector2:
	if not soldier.board.is_empty(): return _board_pose(scene,track,soldier).at
	return _place(scene,track.roof,soldier.cell-soldier.lag,_offset(track,soldier)+soldier.shift)


static func moving(track: Dictionary) -> bool:
	for soldier in track.soldiers:
		if soldier.speed > 0 or soldier.amp > 0.01 or soldier.cell != track.to or not soldier.board.is_empty(): return true
	return false


# Group anchor (label, selection, clicks): its leading soldier's feet.
func point(scene, actor: Dictionary) -> Vector2:
	var track: Dictionary = tracks.get(actor.id,{})
	if track.is_empty() or track.roof != actor.roof or track.soldiers.is_empty():
		return _place(scene,actor.roof,Vector2(actor.x,actor.y),Vector2.ZERO)
	return _soldier_point(scene,track,track.soldiers[0])


func draw(scene) -> void:
	for actor in scene.state.actors: _track(actor) # drawable before the first visual step
	_sparks += 1
	var items := []
	for track in tracks.values():
		for soldier in track.soldiers:
			var item := {"at":_soldier_point(scene,track,soldier),"track":track,"soldier":soldier}
			if not soldier.board.is_empty() and soldier.board.t < soldier.board.dismount and not soldier.board.source.is_empty():
				item.depth = _beast_point(scene,soldier.board.source).y+0.3 # in front of the howdah he leaves
			items.append(item)
	for body in bodies:
		items.append({"at":_place(scene,body.roof,body.cell,body.offset),"body":body})
	for charge in scene.state.charges:
		var entry: Dictionary = charges.get("%d/%d" % [charge.side,charge.slot],{"placed":true,"lit":true})
		if entry.placed: items.append({"at":Geometry.roof_point(scene,charge.side,charge.slot),"charge":entry})
	# Farther first; a man falling is drawn in front of the comrades standing at his depth.
	for track in tracks.values():
		for soldier in track.soldiers: _draw_ladder(scene,track,soldier)
	items.sort_custom(func(a,b): return _depth(a) < _depth(b))
	for item in items:
		if item.has("body"): _draw_body(scene,item.at,item.body)
		elif item.has("charge"): _draw_box(scene,item.at,item.charge.lit)
		else: _draw_soldier(scene,item.at,item.track,item.soldier)


# The ladder is up exactly while he is on it: from the first rung to the last frame before his feet leave the top one.
static func ladder_up(board: Dictionary) -> bool:
	if board.is_empty() or board.hop or board.wagon < 0: return false
	var t: float = board.t-board.dismount
	return t >= board.run and t < board.run+board.climb+STEP*0.5


# A ladder up the end of the wagon being climbed, there only while someone climbs
# it: one rail on the wagon's end edge (where the climbers' hands are) and a
# rung every RUNG, which is also the climb frame's step. Iron colour from the wagon.
func _draw_ladder(scene, track: Dictionary, soldier: Dictionary) -> void:
	var board: Dictionary = soldier.board
	if not ladder_up(board): return
	var out: float = board.out
	var top_row := _place(scene,track.roof,soldier.cell,_offset(track,soldier))
	var edge: float = top_row.x+board.ladder
	var cap := _roof_y(scene,track.roof,board.wagon,edge,0.0)
	var land_y := _roof_y(scene,track.roof,board.wagon,top_row.x+board.land,0.0)
	var bottom: float = land_y+board.height # where the climb starts
	var iron := _iron(scene,track.roof,board.wagon)
	var top: float = cap-LADDER_GRAB
	scene.draw_rect(Rect2(edge+(0.0 if out > 0 else -0.5),top,0.5,bottom-top),iron) # rail on the hull end
	for rung in board.rungs+1: # from the top rung (his feet when the mantle starts) down to the ground
		var y: float = cap+MANTLE_START+rung*board.rung
		scene.draw_rect(Rect2(edge if out > 0 else edge-2.5,y-0.25,2.5,0.5),iron) # rungs stand out toward the climber


# Smallest distance, logical px, from a boarding soldier's contact texels to the
# climbed wagon's drawn body (roof silhouette and end wall) or its ladder: the
# sprite's opaque texels, or his feet when the rig is drawn. 0: touching or overlapping.
func contact_gap(scene, track: Dictionary, soldier: Dictionary) -> float:
	var board: Dictionary = soldier.board
	if board.is_empty() or board.hop or board.wagon < 0: return 0.0
	var stance := stance_of(scene,track,soldier)
	var at: Vector2 = _board_pose(scene,track,soldier).at
	var facing: float = soldier.face if soldier.face != 0 else track.facing
	var points := PackedVector2Array([at])
	if stance.sprite.frame >= 0:
		points = PackedVector2Array()
		for texel in Poses.texels(stance.sprite.family,stance.sprite.frame,track.actor.side): points.append(at+Vector2(facing*texel.x,texel.y))
	var rect: Rect2 = Geometry.wagon(scene,track.roof,board.wagon).rect
	var columns := int(rect.size.x/0.25)+1
	var surface := PackedFloat32Array()
	for column in columns: surface.append(Geometry.drawn_y(scene,track.roof,board.wagon,rect.position.x+column*0.25))
	var gap := INF
	var edge: float = _place(scene,track.roof,soldier.cell,_offset(track,soldier)).x+board.ladder
	var rail_top := surface[clampi(int((edge-rect.position.x)/0.25),0,columns-1)]-LADDER_GRAB
	var rail_bottom: float = _roof_y(scene,track.roof,board.wagon,edge,0.0)+board.height+MANTLE_START
	for point in points:
		gap = minf(gap,_body_distance(point,rect,surface))
		if ladder_up(board): gap = minf(gap,Vector2(absf(point.x-edge),maxf(maxf(rail_top-point.y,point.y-rail_bottom),0.0)).length())
		if gap <= 0.0: break
	return gap


# Distance from a point to the filled region under a wagon's roof profile (columns 0.25px apart).
func _body_distance(point: Vector2, rect: Rect2, surface: PackedFloat32Array) -> float:
	var column := (point.x-rect.position.x)/0.25
	if column >= 0 and column <= surface.size()-1:
		if point.y >= surface[int(column)]: return 0.0
		var best := INF
		for near in range(maxi(0,int(column)-6),mini(surface.size(),int(column)+7)): best = minf(best,point.distance_to(Vector2(rect.position.x+near*0.25,surface[near])))
		return best
	var wall := 0 if column < 0 else surface.size()-1
	var corner := Vector2(rect.position.x+wall*0.25,surface[wall])
	return absf(point.x-corner.x) if point.y >= corner.y else point.distance_to(corner)


# The wagon's own iron: its most common dark, opaque colour (cached per sprite).
var _irons := {}
func _iron(scene, roof: int, index: int) -> Color:
	var texture: Texture2D = Geometry.wagon(scene,roof,index).texture
	var key: int = texture.get_rid().get_id()
	if _irons.has(key): return _irons[key]
	var image := texture.get_image()
	var counts := {}
	for y in range(0,image.get_height(),2):
		for x in range(0,image.get_width(),2):
			var colour := image.get_pixel(x,y)
			if colour.a < 0.9 or colour.s > 0.3 or colour.get_luminance() > 0.3 or colour.get_luminance() < 0.05: continue
			var bucket := Color(snappedf(colour.r,0.04),snappedf(colour.g,0.04),snappedf(colour.b,0.04))
			counts[bucket] = counts.get(bucket,0)+1
	var best := Color("#2a2a30")
	var most := 0
	for bucket in counts:
		if counts[bucket] > most:
			most = counts[bucket]
			best = bucket
	_irons[key] = best
	return best


func _depth(item: Dictionary) -> float:
	return item.get("depth",item.at.y)+(0.5 if item.has("body") and item.body.fall and item.body.t >= item.body.delay else 0.0) # source: authored, half a logical px nearer.


func _draw_soldier(scene, at: Vector2, track: Dictionary, soldier: Dictionary) -> void:
	var actor: Dictionary = track.actor
	var colour := Color.WHITE.lerp(Color(1,0.5,0.45),soldier.recoil/RECOIL*0.7)
	var facing: float = soldier.face if soldier.face != 0 else track.facing
	if actor.mammoth:
		var state := Beast.state(track,soldier)
		Mammoth.draw(scene,scene.world_transform,actor.side,state.kind,state.motion,state.index,at,facing,state.riders)
		return
	if not soldier.board.is_empty() and soldier.board.t < soldier.board.dismount:
		if soldier.board.t >= 0: Mammoth.draw_dismount(scene,scene.world_transform,actor.side,_board_pose(scene,track,soldier).dismount,at,soldier.board.face,colour)
		return # before his turn the howdah's rider layer shows him
	var stance := stance_of(scene,track,soldier)
	var carrying: bool = not soldier.task.is_empty() and not charges.get(soldier.task.key,{"placed":true}).placed
	if stance.sprite.frame >= 0:
		Poses.draw_frame(scene,scene.world_transform,actor.side,at,facing,stance.sprite.family,stance.sprite.frame,colour)
		if carrying and soldier.board.is_empty(): _draw_box(scene,at+Vector2(facing*(Poses.BOX_REACH[0]+BOX_HALF),0),false) # carried to where it is set down
		return
	Rig.draw(scene,scene.world_transform,actor.side,at,facing,stance.rig,colour)
	if carrying: # the planter carries the box until he sets it down
		var low := minf(stance.rig.crouch,1.0)
		_draw_box(scene,at+Vector2(facing*(2.0+1.5*low),-5.5+3.5*low),false)


# How a trooper is posed: the rig pose and the sprite frame (frame -1: none, the
# rig is drawn). The rig's feet centroid and the sprite's pivot are both the
# soldier's point, and the rig crouch is chosen to match the sprite's height, so
# switching between them moves nothing and changes the height by under a pixel.
func stance_of(scene, track: Dictionary, soldier: Dictionary) -> Dictionary:
	var climb := 0.0
	var crouch: float = soldier.crouch
	var amp: float = soldier.amp
	var sprite := {"family":Poses.PLANT,"frame":soldier.plant}
	if not soldier.board.is_empty():
		var board := _board_pose(scene,track,soldier)
		climb = board.climb
		crouch = board.crouch
		if board.amp >= 0: amp = board.amp
		sprite = {"family":Poses.CLIMB,"frame":board.frame}
	var strike: float = 1.0-soldier.strike/STRIKE if soldier.strike > 0 else 0.0
	var rig := Rig.pose(soldier.phase,amp,0.32*amp*(1.0-climb),crouch,strike,soldier.recoil/RECOIL,climb,soldier.breath)
	return {"rig":rig,"sprite":sprite}


# Sprite of a fall at u of DEATH: [family, frame]; the last frame lands at IMPACT and lies.
static func death_frame(kind: int, u: float) -> Array:
	var family := Poses.FALL_FORWARD if kind == 1 else Poses.FALL_BACK
	return [family,floori(clampf(u/IMPACT,0,1)*(Poses.count(family)-1)+0.5)]


# One rider's death: seated slump (hit frames, bracing frame) on the howdah, then the ballistic fall.
# beast_motion/beast_index: the howdah's frame, which the seated rider follows; pair: the sprite of
# both riders falls together; launched: the howdah frame index he topples from (a dying beast).
func _draw_rider(scene, at: Vector2, body: Dictionary, which: int, dt: float, beast_motion: int, beast_index: int, pair: bool, colour: Color, launched := 0) -> void:
	var side: int = body.side
	var facing: float = body.facing
	var launch := _launch(side,beast_motion,launched,which)
	dt = maxf(dt,0.0) # before his turn he sits, as his first slump frame
	var fall := Beast.rider_fall(dt,launch)
	if fall.stage == 0:
		var motion := Mammoth.HIT if fall.frame < 2 else Mammoth.DEATH
		var index: int = fall.frame if fall.frame < 2 else 0
		Mammoth.draw_seated(scene,scene.world_transform,side,motion,index,which,at,facing,Mammoth.rim_shift(side,beast_motion,beast_index,motion,index),colour)
		return
	var foot := at+Vector2(fall.pos.x*facing,fall.pos.y)
	if fall.stage == 2 and not pair: # one man: the trooper's lying sprite
		Poses.draw_frame(scene,scene.world_transform,side,foot,facing,Poses.FALL_BACK,Poses.count(Poses.FALL_BACK)-1,colour)
		return
	var frame: int = fall.frame+1 if pair else (4 if fall.stage == 2 else 2+mini(fall.frame,1))
	Mammoth.draw_faller(scene,scene.world_transform,side,frame,foot,facing,colour)


func _draw_body(scene, at: Vector2, body: Dictionary) -> void:
	var fading: float = body.t-(body.delay+body.span+LIE) if body.fall else body.t
	var colour := Color(1,1,1,clampf(1.0-fading/FADE,0,1))
	if body.has("rider"):
		_draw_rider(scene,at,body,body.rider,body.t-body.delay,Mammoth.STOP,0,body.pair,colour)
		return
	if body.mammoth: # standing until its turn, then every death frame once, lying till it fades
		var kind := Mammoth.variant(body.side,body.count)
		var riders := Mammoth.riders(body.count)
		if body.t < body.delay:
			Mammoth.draw(scene,scene.world_transform,body.side,kind,Mammoth.STOP,0,at,body.facing,riders,colour)
			return
		var dt: float = body.t-body.delay
		var index := Mammoth.death_index(kind,dt/body.span)
		Mammoth.draw(scene,scene.world_transform,body.side,kind,Mammoth.DEATH,index,at,body.facing,0,colour)
		if riders == 0: return
		var launched := Mammoth.death_index(kind,Beast.rider_slump()/body.span) # the howdah's frame when they topple
		for which in ([0,1] if riders == 2 else [1]): # a pair falls as one sprite, drawn with the first
			_draw_rider(scene,at,body,which,dt,Mammoth.DEATH,index,riders == 2,colour,launched)
			if riders == 2 and which == 0: break
		return
	if body.fall and body.t >= body.delay:
		var fall := death_frame(body.kind,(body.t-body.delay)/DEATH)
		Poses.draw_frame(scene,scene.world_transform,body.side,at,body.facing,fall[0],fall[1],colour)
		return
	Rig.draw(scene,scene.world_transform,body.side,at,body.facing,body_rig(body),colour)


# A body that has not started falling stands: unhurt (fading) or wounded, waiting
# his turn, crouched to the height of the fall's first frame.
func body_rig(body: Dictionary) -> Dictionary:
	if not body.fall: return Rig.pose(0,0,0,0,0,0,0,body.breath)
	var first := death_frame(body.kind,0.0)
	return Rig.pose(0,0,0,_matched(body.side,Poses.top(first[0],first[1],body.side)),0,0,0,body.breath)


# Rig crouch whose silhouette top equals a sprite's (cached).
var _matches := {}
func _matched(side: int, top: float) -> float:
	var key := "%d/%.2f" % [side,top]
	if not _matches.has(key): _matches[key] = Rig.crouch_for_top(top,side)
	return _matches[key]


# Dynamite box: dark crate, iron straps, fuse; a lit fuse sputters.
func _draw_box(scene, foot: Vector2, lit: bool) -> void:
	var box := Rect2(foot+Vector2(-1.75,-2.5),Vector2(3.5,2.5))
	scene.draw_rect(box.grow(0.25),Color("#140d08"))
	scene.draw_rect(box,Color("#6b4526"))
	scene.draw_rect(Rect2(box.position,Vector2(box.size.x,0.5)),Color("#8c5d34"))
	for x in [0.75,2.5]: scene.draw_rect(Rect2(box.position+Vector2(x,0),Vector2(0.25,box.size.y)),Color("#7d858d"))
	var tip := box.position+Vector2(2.75,-1.25)
	scene.draw_line(box.position+Vector2(2.0,0),tip,Color("#d8cfb4"),0.25)
	if lit:
		var flicker := float((_sparks*7)%5)/4.0
		scene.draw_rect(Rect2(tip-Vector2(0.25,0.25),Vector2(0.5,0.5)),Color(1,0.85,0.4).lerp(Color(1,0.45,0.1),flicker))
		if _sparks%3 == 0:
			scene.draw_rect(Rect2(tip+Vector2(0.25+flicker*0.5,-0.5-flicker*0.5),Vector2(0.25,0.25)),Color(1,0.95,0.6))
