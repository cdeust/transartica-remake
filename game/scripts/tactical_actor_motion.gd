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
const STEP := 1.0/50.0
const SPRINT := 22.0 # source: authored top speed, logical px/s (~1.7 body heights/s).
const ACCEL := 140.0 # source: authored, logical px/s².
const BRAKE := 110.0 # source: authored, logical px/s².
const CLIMB := 24.0 # source: authored climbing speed up a wagon side, logical px/s.
const RUNG := 3.0 # source: authored climbing step, logical px.
const WAGON_SIDE := 25.0 # source: roof 38 above the top train baseline 63, logical px.
const MAMMOTH_SPEED := 14.0 # source: authored heavy gait, logical px/s.
const STRIDE_PX := Rig.STRIDE/Rig.PER # one step of the rig, logical px.
const MAMMOTH_STRIDE := 7.0 # source: authored, logical px per step.
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
		tracks[actor.id] = {"to":cell,"roof":actor.roof,"facing":1.0,"count":actor.count,"engaged":0.0,"shed":0,"soldiers":[],"actor":actor}
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


# Visible soldiers follow the group's strength. In a melee every loss fells a
# visible man, at most two per report, one after the other; when the group is
# still larger than what is drawn, a comrade runs in to fill the gap.
func _muster(track: Dictionary, actor: Dictionary, fighting: bool) -> void:
	var wanted := 1 if actor.mammoth else clampi(actor.count,1,VISIBLE)
	var losses: int = track.count-actor.count
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
	if fighting and losses > 0 and not track.soldiers.is_empty(): track.soldiers[0].recoil = RECOIL
	while track.soldiers.size() < wanted:
		track.soldiers.append(_soldier(track.to,track.soldiers.size()))


func _soldier(cell: Vector2, slot: int) -> Dictionary:
	return {"cell":cell,"speed":0.0,"amp":0.0,"phase":_rng.randf()*TAU,"delay":0.0,
		"vmul":_rng.randf_range(0.92,1.08),"breath":_rng.randf()*TAU,"strike":0.0,"recoil":0.0,
		"slot":slot%VISIBLE,"offset":Vector2.ZERO,"shift":Vector2.ZERO,"shift_to":Vector2.ZERO,
		"shift_speed":0.0,"face":0.0,"board":{},"task":{},"crouch":0.0}


func _drop(track: Dictionary, soldier: Dictionary, fell: bool, delay: float) -> void:
	var actor: Dictionary = track.actor
	var roll := _rng.randf()
	bodies.append({"roof":track.roof,"cell":soldier.cell,"offset":_offset(track,soldier)+soldier.shift,
		"facing":soldier.face if soldier.face != 0 else track.facing,"side":actor.side,"mammoth":actor.mammoth,
		"count":actor.count,"t":0.0,"delay":delay,"fall":fell and not actor.mammoth,
		"kind":0 if roll < 0.4 else (1 if roll < 0.75 else 2),"landed":false,"breath":soldier.breath})


func _age_bodies(scene) -> void:
	for body in bodies:
		body.t += STEP
		if body.fall and not body.landed and (body.t-body.delay)/Rig.DEATH >= Rig.IMPACT:
			body.landed = true # snow kicked up where the body hits
			var at := _place(scene,body.roof,body.cell,body.offset)+Vector2(body.facing*(4.0 if body.kind == 1 else -5.0),0)
			scene.living.add("dust",at+Vector2(scene.camera,0),Vector2.UP,0.12) # source: authored light puff
	bodies = bodies.filter(func(body): return body.t < (body.delay+Rig.DEATH+LIE+FADE if body.fall else FADE))


# Sprint kinematics: accelerate, hold top speed, brake to stop on the cell.
func _run(track: Dictionary, soldier: Dictionary) -> void:
	var mammoth: bool = track.actor.mammoth
	soldier.strike = maxf(0.0,soldier.strike-STEP)
	soldier.recoil = maxf(0.0,soldier.recoil-STEP)
	soldier.breath += STEP*2.4 # source: authored breathing rate, rad/s.
	var stride: float = MAMMOTH_STRIDE if mammoth else STRIDE_PX
	if not soldier.board.is_empty():
		_climbing(soldier)
		return
	_task(soldier)
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


# Dynamite: run to the charge, kneel, set the box, light the fuse, rise, return.
func _task(soldier: Dictionary) -> void:
	var task: Dictionary = soldier.task
	soldier.crouch = 0.0
	if task.is_empty(): return
	task.t += STEP
	if not task.arrived:
		if soldier.shift.distance_to(soldier.shift_to) < 0.05 or task.t > 1.2:
			task.arrived = true
			task.t = 0.0
		return
	var t: float = task.t
	var entry: Dictionary = charges.get(task.key,{})
	if t < KNEEL: soldier.crouch = 1.2*t/KNEEL
	elif t < KNEEL+SET+LIGHT: soldier.crouch = 1.2
	elif t < KNEEL+SET+LIGHT+RISE: soldier.crouch = 1.2*(1.0-(t-KNEEL-SET-LIGHT)/RISE)
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
	var lift := Vector2(0,-12) if source.actor.mammoth else Vector2.ZERO # riders step off the howdah
	var start: Vector2 = source.soldiers[0].cell if not source.soldiers.is_empty() else source.to
	for index in track.soldiers.size():
		_start_climb(scene,track,track.soldiers[index],start,FIELD_FORMATION[index%VISIBLE]+lift,index*0.12)


# Climbs go up the end ladder of the wagon nearest the runner (ladders drawn
# 3px inside each wagon end), then he runs along the roof to his slot.
func _start_climb(scene, track: Dictionary, soldier: Dictionary, from_cell: Vector2, from_offset: Vector2, delay: float) -> void:
	var start := _place(scene,-1,from_cell,from_offset)
	var top := _place(scene,track.roof,soldier.cell,_offset(track,soldier))
	var height := minf(start.y-top.y,WAGON_SIDE)
	var climbing := height > 6.0
	if not climbing: height = start.y-top.y
	var ladder := 0.0
	var index := Geometry.wagon_at(scene,track.roof,top.x)
	if climbing and index >= 0:
		var rect: Rect2 = Geometry.wagon(scene,track.roof,index).rect
		var left := rect.position.x+3.0 # source: authored ladder inset, logical px.
		var right := rect.end.x-3.0
		ladder = (left if absf(left-top.x) < absf(right-top.x) else right)-top.x
		if absf(ladder) > 32.0: ladder = 0.0 # source: half a 64px wagon; longer bodies climb in place
	var foot := Vector2(top.x+ladder,top.y+height)
	soldier.board = {"from_cell":from_cell,"from_offset":from_offset,"t":-delay,"height":height,"ladder":ladder,
		"run":start.distance_to(foot)/SPRINT,"climb":height/CLIMB if climbing else 0.35,"hop":not climbing,"rise":0.3}
	soldier.face = signf(foot.x-start.x) if absf(foot.x-start.x) > 0.5 else 0.0


func _climbing(soldier: Dictionary) -> void:
	var board: Dictionary = soldier.board
	board.t += STEP
	var t: float = board.t
	if t < 0: return
	if t < board.run: # running to the wagon
		soldier.phase += SPRINT*STEP/STRIDE_PX*PI
		soldier.amp = move_toward(soldier.amp,1.0,STEP*6.0)
	elif t < board.run+board.climb: # rung over rung up the end ladder, facing the wagon
		if not board.hop: soldier.phase += CLIMB*STEP/RUNG*PI
		soldier.amp = 0.0 if board.hop else 1.0
		if board.ladder != 0: soldier.face = -signf(board.ladder)
	else:
		soldier.amp = move_toward(soldier.amp,0.0,STEP*6.0)
	if t >= board.run+board.climb+board.rise:
		soldier.shift = Vector2(board.ladder,0) # then along the roof to his slot
		soldier.shift_to = Vector2.ZERO
		soldier.board = {}
		soldier.face = 0.0


func _board_pose(scene, track: Dictionary, soldier: Dictionary) -> Dictionary:
	var board: Dictionary = soldier.board
	var start := _place(scene,-1,board.from_cell,board.from_offset)
	var top := _place(scene,track.roof,soldier.cell,_offset(track,soldier))
	top.x += board.ladder
	var foot := Vector2(top.x,top.y+board.height)
	var t: float = maxf(board.t,0.0)
	if t < board.run:
		return {"at":start.lerp(foot,t/maxf(board.run,0.001)),"climb":0.0,"crouch":0.0}
	if t < board.run+board.climb:
		var u: float = (t-board.run)/board.climb
		if board.hop: # vault: crouch, jump, land
			return {"at":foot.lerp(top,u)+Vector2(0,-6.0*sin(PI*u)),"climb":0.0,"crouch":0.5*(1.0-sin(PI*u))}
		return {"at":foot.lerp(top,u),"climb":1.0,"crouch":0.0}
	var rise: float = (t-board.run-board.climb)/board.rise
	return {"at":top,"climb":0.0,"crouch":1.0-clampf(rise,0,1)} # mantle and stand


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
	striker.strike = STRIKE
	if not target.soldiers.is_empty() and target.soldiers[0].recoil <= 0: target.soldiers[0].recoil = RECOIL*0.6


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
		soldier.shift_to = Vector2(screen-_offset(planter,soldier).x-side*3.0,0) # source: authored, kneels 3px short of the box.
		soldier.face = side
		soldier.task = {"key":key,"t":0.0,"arrived":false}
		current[key] = {"placed":false,"lit":false}
	charges = current


func _offset(track: Dictionary, soldier: Dictionary) -> Vector2:
	if soldier.offset != Vector2.ZERO or track.actor.mammoth: return soldier.offset
	return (ROOF_FORMATION if track.roof >= 0 else FIELD_FORMATION)[soldier.slot]


func _place(scene, roof: int, cell: Vector2, offset: Vector2) -> Vector2:
	if roof >= 0: return Geometry.roof_point_at(scene,roof,cell.x-offset.x/16.0)
	return scene._field_point(cell.x,cell.y)+offset


func _soldier_point(scene, track: Dictionary, soldier: Dictionary) -> Vector2:
	if not soldier.board.is_empty(): return _board_pose(scene,track,soldier).at
	return _place(scene,track.roof,soldier.cell,_offset(track,soldier)+soldier.shift)


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


func draw(scene, art) -> void:
	for actor in scene.state.actors: _track(actor) # drawable before the first visual step
	_sparks += 1
	var items := []
	for track in tracks.values():
		for soldier in track.soldiers:
			items.append({"at":_soldier_point(scene,track,soldier),"track":track,"soldier":soldier})
	for body in bodies:
		items.append({"at":_place(scene,body.roof,body.cell,body.offset),"body":body})
	for charge in scene.state.charges:
		var entry: Dictionary = charges.get("%d/%d" % [charge.side,charge.slot],{"placed":true,"lit":true})
		if entry.placed: items.append({"at":Geometry.roof_point(scene,charge.side,charge.slot),"charge":entry})
	items.sort_custom(func(a,b): return a.at.y < b.at.y) # farther first
	for item in items:
		if item.has("body"): _draw_body(scene,art,item.at,item.body)
		elif item.has("charge"): _draw_box(scene,item.at,item.charge.lit)
		else: _draw_soldier(scene,art,item.at,item.track,item.soldier)


func _draw_soldier(scene, art, at: Vector2, track: Dictionary, soldier: Dictionary) -> void:
	var actor: Dictionary = track.actor
	var colour := Color.WHITE.lerp(Color(1,0.5,0.45),soldier.recoil/RECOIL*0.7)
	var facing: float = soldier.face if soldier.face != 0 else track.facing
	if actor.mammoth:
		var bob: float = -absf(sin(soldier.phase))*0.5*soldier.amp # source: authored stride lift, logical px.
		art.draw_pose(scene,art.pose_for(actor),at+Vector2(0,bob),facing,colour)
		return
	var climb := 0.0
	var crouch: float = soldier.crouch
	if not soldier.board.is_empty():
		var board := _board_pose(scene,track,soldier)
		climb = board.climb
		crouch = board.crouch
	var strike: float = 1.0-soldier.strike/STRIKE if soldier.strike > 0 else 0.0
	var rig := Rig.pose(soldier.phase,soldier.amp,0.32*soldier.amp*(1.0-climb),crouch,strike,soldier.recoil/RECOIL,climb,soldier.breath)
	Rig.draw(scene,scene.world_transform,actor.side,at,facing,rig,colour)
	# The planter carries the box until he sets it down.
	if not soldier.task.is_empty() and not charges.get(soldier.task.key,{"placed":true}).placed:
		var low := minf(crouch,1.0)
		_draw_box(scene,at+Vector2(facing*(2.0+1.5*low),-5.5+3.5*low),false)


func _draw_body(scene, art, at: Vector2, body: Dictionary) -> void:
	var fading: float = body.t-(body.delay+Rig.DEATH+LIE) if body.fall else body.t
	var colour := Color(1,1,1,clampf(1.0-fading/FADE,0,1))
	if body.mammoth:
		art.draw_pose(scene,9 if body.count > 1 else 8,at,body.facing,colour)
		return
	var rig: Dictionary
	if not body.fall: rig = Rig.pose(0,0,0,0,0,0,0,body.breath)
	elif body.t < body.delay: rig = Rig.pose(0,0,0,0.2,0,0.6,0,body.breath) # wounded, still standing his turn
	else: rig = Rig.dying(body.kind,clampf((body.t-body.delay)/Rig.DEATH,0,1))
	Rig.draw(scene,scene.world_transform,body.side,at,body.facing,rig,colour)


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
