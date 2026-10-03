extends "res://scripts/tactical_actor_motion_constants.gd"

# MIT. Pure extraction of Opus actor motion; caller owns all mutable state.

static func _task(owner_actor, soldier: Dictionary, side: int) -> void:
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
	var entry: Dictionary = owner_actor.charges.get(task.key,{})
	# The rig crouches down to the kneel pose whose height matches the sprite's,
	# the sprite takes over for the set and the light, and the rig rises from that
	# same crouch (hard switches at equal height and feet, no blending).
	var done = KNEEL+SET+LIGHT
	var kneel = minf(owner_actor._matched(side,Poses.top(Poses.PLANT,0,side)),KNEEL_CROUCH)
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
static func _board(owner_actor, scene, track: Dictionary, cell: Vector2) -> void:
	var froms = []
	for soldier in track.soldiers:
		froms.append({"cell":soldier.cell,"offset":owner_actor._offset(track,soldier)+soldier.shift})
	owner_actor._snap(track,cell)
	for index in track.soldiers.size():
		owner_actor._start_climb(scene,track,track.soldiers[index],froms[index].cell,froms[index].offset,index*0.12)


# 0x123a: riders and infantry crossing to the player's roof leave a field
# group of the same side; the new roof group climbs from that group's place.
static func _board_from_shedder(owner_actor, scene, track: Dictionary) -> void:
	var actor: Dictionary = track.actor
	var here = owner_actor._place(scene,actor.roof,track.to,Vector2.ZERO).x
	var source = null
	var best = INF
	for other in owner_actor.tracks.values():
		if other == track or other.shed <= 0 or other.roof >= 0 or other.actor.side != actor.side: continue
		var distance = absf(owner_actor._place(scene,-1,other.to,Vector2.ZERO).x-here)
		if distance < best:
			best = distance
			source = other
	if source == null: return
	var start: Vector2 = source.soldiers[0].cell if not source.soldiers.is_empty() else source.to
	if not source.actor.mammoth:
		for index in track.soldiers.size(): owner_actor._start_climb(scene,track,track.soldiers[index],start,FIELD_FORMATION[index%VISIBLE],index*0.12)
		return
	# Riders step off the howdah one after the other: stand on its rim, swing a leg over, hang, drop, land
	# beside the beast, then run to the wagon; until each one's turn the howdah's rider layer shows him.
	var beast = owner_actor._beast_point(scene,source)
	var offset: Vector2 = beast-scene._field_point(start.x,start.y)
	for index in track.soldiers.size():
		var soldier: Dictionary = track.soldiers[index]
		owner_actor._start_climb(scene,track,soldier,start,offset,index*DISMOUNT_GAP,{"source":source,"which":index%Mammoth.SEATED})
		source.leaving.append(soldier)


# Climbs go up the end ladder of the wagon nearest the runner (ladders drawn
# 3px inside each wagon end), then he runs along the roof to his slot.
# ride: {source, which} when he steps off a howdah first (dismount frames, then he runs from where he lands).
static func _start_climb(owner_actor, scene, track: Dictionary, soldier: Dictionary, from_cell: Vector2, from_offset: Vector2, delay: float, ride := {}) -> void:
	var start = owner_actor._place(scene,-1,from_cell,from_offset)
	var top = owner_actor._place(scene,track.roof,soldier.cell,owner_actor._offset(track,soldier))
	var height = minf(start.y-top.y,WAGON_SIDE)
	var climbing = height > 6.0
	if not climbing: height = start.y-top.y
	var ladder = 0.0 # screen offset, from his slot, of the wagon's end edge where he climbs
	var out = 1.0 # which way is out from that edge: +1 right
	var index = Geometry.wagon_at(scene,track.roof,top.x)
	if climbing and index >= 0:
		var rect: Rect2 = Geometry.wagon(scene,track.roof,index).rect
		var left = owner_actor._hull_end(scene,track.roof,index,-1.0)
		var right = owner_actor._hull_end(scene,track.roof,index,1.0)
		ladder = (left if absf(left-top.x) < absf(right-top.x) else right)-top.x
		if absf(ladder) > 32.0: ladder = 0.0 # source: half a 64px wagon; longer bodies climb in place
		else: out = 1.0 if top.x+ladder > rect.get_center().x else -1.0
	var wagon: int = index if ladder != 0.0 else -1
	var land = ladder-out*LAND # screen offset, from his slot, of where the mantle puts his feet
	var roof = Vector2(top.x+land,owner_actor._roof_y(scene,track.roof,wagon,top.x+land,top.y))
	var cap = owner_actor._roof_y(scene,track.roof,wagon,top.x+ladder,top.y) # the roof's end cap at the ladder
	var foot = Vector2(top.x+ladder+out*Poses.hand(0).x,roof.y+height)
	# He climbs from the ground to the top rung, where his feet are when the mantle starts and his
	# hand is on the roof edge. Rungs are evenly spaced and their count is 2 mod 4, so the last
	# rung frame is always the one that reaches the edge (frame 1).
	var climbed = maxf(foot.y-(cap+MANTLE_START),RUNG*2)
	var rungs = 4*maxi(0,roundi((climbed/RUNG-2.0)/4.0))+2
	var heading = signf(foot.x-start.x) if absf(foot.x-start.x) > 0.5 else 0.0
	var dismount = 0.0
	var drop = Vector2.ZERO # where he lands from the beast's point
	if not ride.is_empty():
		var seat = Mammoth.seat(ride.source.actor.side,ride.which)
		drop = Vector2((Mammoth.rim(ride.source.actor.side).x-HANG_OUT)*ride.source.facing,0) # behind the rump
		from_offset += drop
		start += drop
		for time in DISMOUNT: dismount += time
	soldier.board = {"from_cell":from_cell,"from_offset":from_offset,"t":-delay,"height":height,"ladder":ladder,"out":out,"land":land,"wagon":wagon,"rungs":rungs,"rung":climbed/rungs,
		"run":start.distance_to(foot)/SPRINT,"climb":climbed/CLIMB if climbing else 0.35,"hop":not climbing,"rise":0.45,
		"dismount":dismount,"source":ride.get("source",{}),"which":ride.get("which",0),"face":heading}
	soldier.face = heading


static func _climbing(owner_actor, soldier: Dictionary) -> void:
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
static func _board_pose(owner_actor, scene, track: Dictionary, soldier: Dictionary) -> Dictionary:
	var board: Dictionary = soldier.board
	var start = owner_actor._place(scene,-1,board.from_cell,board.from_offset)
	var top = owner_actor._place(scene,track.roof,soldier.cell,owner_actor._offset(track,soldier))
	var edge_x: float = top.x+board.ladder
	var land_x: float = top.x+board.land
	var out: float = board.out
	var roof = Vector2(land_x,owner_actor._roof_y(scene,track.roof,board.wagon,land_x,top.y))
	var cap = owner_actor._roof_y(scene,track.roof,board.wagon,edge_x,top.y) # the roof's end cap at the ladder
	var foot = Vector2(edge_x+out*Poses.hand(0).x,roof.y+board.height)
	var pose = {"at":foot,"climb":0.0,"crouch":0.0,"frame":-1,"amp":-1.0,"dismount":-1}
	if board.t < board.dismount: return owner_actor._dismount_pose(scene,board,pose)
	var t: float = maxf(board.t-board.dismount,0.0)
	if t < board.run:
		pose.at = start.lerp(foot,t/maxf(board.run,0.001)) # source: f50c3cd:game/scripts/tactical_actor_motion.gd:472; existing denominator guard for zero-duration run.
		return pose
	if t < board.run+board.climb+STEP*0.5:
		var u: float = clampf((t-board.run)/board.climb,0,1)
		if board.hop: # vault: crouch, jump, land
			pose.at = foot.lerp(roof,u)+Vector2(0,-6.0*sin(PI*u))
			pose.crouch = 0.5*(1.0-sin(PI*u))
			return pose
		# One rung frame per rung climbed, his hand on the rail at the hull end the whole way.
		var frame = mini(int(u*board.rungs),board.rungs-1)%MANTLE
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
	var pull = clampf(rise/MANTLE_HOLD,0,1)
	var from = Vector2(edge_x+out*Poses.hand(MANTLE).x,cap+MANTLE_START)
	var to = Vector2(roof.x,roof.y+MANTLE_SINK) # rear foot just under the roof surface at the landing point, front knee up
	pose.at = Vector2(lerpf(from.x,to.x,smoothstep(0,1,minf(pull*MANTLE_SWING,1.0))),lerpf(from.y,to.y,smoothstep(0,1,pull)))
	if rise >= MANTLE_HOLD: pose.at = roof
	if rise < MANTLE_HOLD: pose.frame = MANTLE
	pose.crouch = owner_actor._matched(track.actor.side,Poses.top(Poses.CLIMB,MANTLE,track.actor.side))*(1.0-clampf((rise-MANTLE_HOLD)/(1.0-MANTLE_HOLD),0,1))
	pose.amp = 0.0
	return pose


# Where a mammoth group stands (its drawn feet), or its target cell once it is gone.
static func _beast_point(owner_actor, scene, source: Dictionary) -> Vector2:
	if source.soldiers.is_empty(): return owner_actor._place(scene,-1,source.to,Vector2.ZERO)
	return owner_actor._soldier_point(scene,source,source.soldiers[0])


# A rider stepping off a howdah: which dismount frame, and where his feet are. Frames 0-1 stand
# on the howdah's rim at his seat (following the beast), 2 hangs from the rim, 3 drops, 4 lands
# where the run to the wagon starts.
static func _dismount_pose(owner_actor, scene, board: Dictionary, pose: Dictionary) -> Dictionary:
	var source: Dictionary = board.source
	var side: int = source.actor.side
	var beast = owner_actor._beast_point(scene,source)
	var seat = Mammoth.seat(side,board.which)
	var rim = beast+Vector2(seat.x*source.facing,seat.y)
	var edge = beast+Vector2((Mammoth.rim(side).x-HANG_OUT)*source.facing,Mammoth.rim(side).y) # outside the rear end of the rim
	var landing = owner_actor._place(scene,-1,board.from_cell,board.from_offset)
	var hang = edge+Vector2(0,Mammoth.dismount_height(side,2)-0.5)
	var t = maxf(board.t,0.0)
	var k = 0
	for time in DISMOUNT:
		if t < time or k == DISMOUNT.size()-1: break
		t -= time
		k += 1
	var u = clampf(t/DISMOUNT[k],0,1)
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
static func _hull_end(owner_actor, scene, roof: int, index: int, out: float) -> float:
	var rect: Rect2 = Geometry.wagon(scene,roof,index).rect
	var edge = rect.end.x if out > 0 else rect.position.x
	var flat = Geometry.drawn_y(scene,roof,index,edge-out*9.0)
	var x = edge
	while absf(x-edge) < 9.0 and Geometry.drawn_y(scene,roof,index,x) > flat+HULL_DROP: x -= out*0.25
	return x


# Roof surface under x of the wagon being climbed (clamped to it); fallback outside any wagon.
static func _roof_y(owner_actor, scene, roof: int, index: int, x: float, fallback: float) -> float:
	if index < 0: return fallback
	var rect: Rect2 = Geometry.wagon(scene,roof,index).rect
	return Geometry.drawn_y(scene,roof,index,clampf(x,rect.position.x,rect.end.x))


# WDECOR0x2679 melee reports the attacker's cell; both groups turn to fight.
