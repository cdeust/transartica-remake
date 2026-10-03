extends "res://scripts/tactical_actor_motion_constants.gd"

# MIT. Actor state/cadence retained; boarding and drawing delegated without rule changes.
const _boarding = preload("res://scripts/tactical_actor_motion_boarding.gd")
const _drawing = preload("res://scripts/tactical_actor_motion_drawing.gd")

var tracks := {}
var bodies := []
var charges := {} # "side/slot" → {"placed","lit"}
var _melees := []
var _rng := RandomNumberGenerator.new()
var _sparks := 0
var _serial := 0


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
		if actor.count > 0: track.alive = actor.count # a killed beast is drawn with the strength it died with
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
	_prune_leaving()


# Riders still to step off a howdah whose destination group is gone (merged, killed, restored)
# no longer hold a seat in it.
func _prune_leaving() -> void:
	var alive := {}
	for track in tracks.values():
		for soldier in track.soldiers: alive[soldier.uid] = true # by number: soldiers refer to their tracks, hashing one would not end
	for track in tracks.values():
		track.leaving = track.leaving.filter(func(soldier): return alive.has(soldier.uid) and not soldier.board.is_empty())


func _track(actor: Dictionary) -> Dictionary:
	if not tracks.has(actor.id):
		var cell := Vector2(actor.x,actor.y)
		tracks[actor.id] = {"to":cell,"roof":actor.roof,"facing":1.0,"count":actor.count,"engaged":0.0,"shed":0,"soldiers":[],"leaving":[],"dying":[],"alive":actor.count,"actor":actor}
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
	_serial += 1
	return {"uid":_serial,"cell":cell,"speed":0.0,"amp":0.0,"phase":_rng.randf()*TAU,"delay":0.0,
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
		"count":track.alive,"t":0.0,"delay":delay,"fall":fell or actor.mammoth,"span":Beast.DEATH if actor.mammoth else DEATH,
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
	elif remaining > 0.001: # source: f50c3cd:game/scripts/tactical_actor_motion.gd:282; authored arrival epsilon, preserved by actor_motion fixture.
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
	if gap > 0.001 and soldier.delay <= 0: # source: f50c3cd:game/scripts/tactical_actor_motion.gd:294; authored formation-settle epsilon, unchanged.
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
	_boarding._task(self, soldier, side)


func _board(scene, track: Dictionary, cell: Vector2) -> void:
	_boarding._board(self, scene, track, cell)


func _board_from_shedder(scene, track: Dictionary) -> void:
	_boarding._board_from_shedder(self, scene, track)


func _start_climb(scene, track: Dictionary, soldier: Dictionary, from_cell: Vector2, from_offset: Vector2, delay: float, ride := {}) -> void:
	_boarding._start_climb(self, scene, track, soldier, from_cell, from_offset, delay, ride)


func _climbing(soldier: Dictionary) -> void:
	_boarding._climbing(self, soldier)


func _board_pose(scene, track: Dictionary, soldier: Dictionary) -> Dictionary:
	return _boarding._board_pose(self, scene, track, soldier)


func _beast_point(scene, source: Dictionary) -> Vector2:
	return _boarding._beast_point(self, scene, source)


func _dismount_pose(scene, board: Dictionary, pose: Dictionary) -> Dictionary:
	return _boarding._dismount_pose(self, scene, board, pose)


func _hull_end(scene, roof: int, index: int, out: float) -> float:
	return _boarding._hull_end(self, scene, roof, index, out)


func _roof_y(scene, roof: int, index: int, x: float, fallback: float) -> float:
	return _boarding._roof_y(self, scene, roof, index, x, fallback)


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
	return _drawing.soldier_rects(self, scene)


func _offset(track: Dictionary, soldier: Dictionary) -> Vector2:
	return _drawing._offset(self, track, soldier)


func _place(scene, roof: int, cell: Vector2, offset: Vector2) -> Vector2:
	return _drawing._place(self, scene, roof, cell, offset)


func _soldier_point(scene, track: Dictionary, soldier: Dictionary) -> Vector2:
	return _drawing._soldier_point(self, scene, track, soldier)


static func moving(track: Dictionary) -> bool:
	return _drawing.moving(track)


func point(scene, actor: Dictionary) -> Vector2:
	return _drawing.point(self, scene, actor)


func draw(scene) -> void:
	_drawing.draw(self, scene)


static func ladder_up(board: Dictionary) -> bool:
	return _drawing.ladder_up(board)


func _draw_ladder(scene, track: Dictionary, soldier: Dictionary) -> void:
	_drawing._draw_ladder(self, scene, track, soldier)


func contact_gap(scene, track: Dictionary, soldier: Dictionary) -> float:
	return _drawing.contact_gap(self, scene, track, soldier)


func _body_distance(point: Vector2, rect: Rect2, surface: PackedFloat32Array) -> float:
	return _drawing._body_distance(self, point, rect, surface)


func _iron(scene, roof: int, index: int) -> Color:
	return _drawing._iron(self, scene, roof, index)


func _depth(item: Dictionary) -> float:
	return _drawing._depth(self, item)


func _draw_soldier(scene, at: Vector2, track: Dictionary, soldier: Dictionary) -> void:
	_drawing._draw_soldier(self, scene, at, track, soldier)


func stance_of(scene, track: Dictionary, soldier: Dictionary) -> Dictionary:
	return _drawing.stance_of(self, scene, track, soldier)


static func death_frame(kind: int, u: float) -> Array:
	return _drawing.death_frame(kind, u)


func _draw_rider(scene, at: Vector2, body: Dictionary, which: int, dt: float, beast_motion: int, beast_index: int, pair: bool, colour: Color, launched := 0) -> void:
	_drawing._draw_rider(self, scene, at, body, which, dt, beast_motion, beast_index, pair, colour, launched)


func _draw_body(scene, at: Vector2, body: Dictionary) -> void:
	_drawing._draw_body(self, scene, at, body)


func body_rig(body: Dictionary) -> Dictionary:
	return _drawing.body_rig(self, body)


func _matched(side: int, top: float) -> float:
	return _drawing._matched(self, side, top)


func _draw_box(scene, foot: Vector2, lit: bool) -> void:
	_drawing._draw_box(self, scene, foot, lit)



var _irons := {}
var _matches := {}
