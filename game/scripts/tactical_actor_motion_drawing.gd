extends "res://scripts/tactical_actor_motion_constants.gd"

# MIT. Pure extraction of Opus actor motion; caller owns all mutable state.

static func soldier_rects(owner_actor, scene) -> Array:
	var rects = []
	for track in owner_actor.tracks.values():
		for soldier in track.soldiers:
			if not soldier.board.is_empty() and soldier.board.t < 0: continue # still seated: drawn with the howdah
			var at = owner_actor._soldier_point(scene,track,soldier)
			if track.actor.mammoth:
				var state = Beast.state(track,soldier)
				rects.append(Mammoth.bounds(track.actor.side,state.kind,state.motion,state.index,at,track.facing,state.riders))
				continue
			var facing: float = soldier.face if soldier.face != 0 else track.facing
			if soldier.board.is_empty() and soldier.plant >= 0: rects.append(Poses.bounds(at,facing,Poses.PLANT,soldier.plant,track.actor.side))
			else: rects.append(Rect2(at+Vector2(-4,-13),Vector2(8,12))) # source: standing rig, 13 px tall, ~8 wide with its rifle; boots may meet a label below.
	return rects


static func _offset(owner_actor, track: Dictionary, soldier: Dictionary) -> Vector2:
	if soldier.offset != Vector2.ZERO or track.actor.mammoth: return soldier.offset
	return (ROOF_FORMATION if track.roof >= 0 else FIELD_FORMATION)[soldier.slot]


static func _place(owner_actor, scene, roof: int, cell: Vector2, offset: Vector2) -> Vector2:
	if roof >= 0: return Geometry.roof_point_at(scene,roof,cell.x-offset.x/16.0)
	return scene._field_point(cell.x,cell.y)+offset


static func _soldier_point(owner_actor, scene, track: Dictionary, soldier: Dictionary) -> Vector2:
	if not soldier.board.is_empty(): return owner_actor._board_pose(scene,track,soldier).at
	return owner_actor._place(scene,track.roof,soldier.cell-soldier.lag,owner_actor._offset(track,soldier)+soldier.shift)


static func moving(track: Dictionary) -> bool:
	for soldier in track.soldiers:
		if soldier.speed > 0 or soldier.amp > 0.01 or soldier.cell != track.to or not soldier.board.is_empty(): return true
	return false


# Group anchor (label, selection, clicks): its leading soldier's feet.
static func point(owner_actor, scene, actor: Dictionary) -> Vector2:
	var track: Dictionary = owner_actor.tracks.get(actor.id,{})
	if track.is_empty() or track.roof != actor.roof or track.soldiers.is_empty():
		return owner_actor._place(scene,actor.roof,Vector2(actor.x,actor.y),Vector2.ZERO)
	return owner_actor._soldier_point(scene,track,track.soldiers[0])


static func draw(owner_actor, scene) -> void:
	for actor in scene.state.actors: owner_actor._track(actor) # drawable before the first visual step
	owner_actor._sparks += 1
	var items = []
	for track in owner_actor.tracks.values():
		for soldier in track.soldiers:
			var item = {"at":owner_actor._soldier_point(scene,track,soldier),"track":track,"soldier":soldier}
			if not soldier.board.is_empty() and soldier.board.t < soldier.board.dismount and not soldier.board.source.is_empty():
				item.depth = owner_actor._beast_point(scene,soldier.board.source).y+0.3 # in front of the howdah he leaves
			items.append(item)
	for body in owner_actor.bodies:
		items.append({"at":owner_actor._place(scene,body.roof,body.cell,body.offset),"body":body})
	for charge in scene.state.charges:
		var entry: Dictionary = owner_actor.charges.get("%d/%d" % [charge.side,charge.slot],{"placed":true,"lit":true})
		if entry.placed: items.append({"at":Geometry.roof_point(scene,charge.side,charge.slot),"charge":entry})
	# Farther first; a man falling is drawn in front of the comrades standing at his depth.
	for track in owner_actor.tracks.values():
		for soldier in track.soldiers: owner_actor._draw_ladder(scene,track,soldier)
	items.sort_custom(func(a,b): return owner_actor._depth(a) < owner_actor._depth(b))
	for item in items:
		if item.has("body"): owner_actor._draw_body(scene,item.at,item.body)
		elif item.has("charge"): owner_actor._draw_box(scene,item.at,item.charge.lit)
		else: owner_actor._draw_soldier(scene,item.at,item.track,item.soldier)


# The ladder is up exactly while he is on it: from the first rung to the last frame before his feet leave the top one.
static func ladder_up(board: Dictionary) -> bool:
	if board.is_empty() or board.hop or board.wagon < 0: return false
	var t: float = board.t-board.dismount
	return t >= board.run and t < board.run+board.climb+STEP*0.5


# A ladder up the end of the wagon being climbed, there only while someone climbs
# it: one rail on the wagon's end edge (where the climbers' hands are) and a
# rung every RUNG, which is also the climb frame's step. Iron colour from the wagon.
static func _draw_ladder(owner_actor, scene, track: Dictionary, soldier: Dictionary) -> void:
	var board: Dictionary = soldier.board
	if not owner_actor.ladder_up(board): return
	var out: float = board.out
	var top_row = owner_actor._place(scene,track.roof,soldier.cell,owner_actor._offset(track,soldier))
	var edge: float = top_row.x+board.ladder
	var cap = owner_actor._roof_y(scene,track.roof,board.wagon,edge,0.0)
	var land_y = owner_actor._roof_y(scene,track.roof,board.wagon,top_row.x+board.land,0.0)
	var bottom: float = land_y+board.height # where the climb starts
	var iron = owner_actor._iron(scene,track.roof,board.wagon)
	var top: float = cap-LADDER_GRAB
	scene.draw_rect(Rect2(edge+(0.0 if out > 0 else -0.5),top,0.5,bottom-top),iron) # rail on the hull end
	for rung in board.rungs+1: # from the top rung (his feet when the mantle starts) down to the ground
		var y: float = cap+MANTLE_START+rung*board.rung
		scene.draw_rect(Rect2(edge if out > 0 else edge-2.5,y-0.25,2.5,0.5),iron) # rungs stand out toward the climber


# Smallest distance, logical px, from a boarding soldier's contact texels to the
# climbed wagon's drawn body (roof silhouette and end wall) or its ladder: the
# sprite's opaque texels, or his feet when the rig is drawn. 0: touching or overlapping.
static func contact_gap(owner_actor, scene, track: Dictionary, soldier: Dictionary) -> float:
	var board: Dictionary = soldier.board
	if board.is_empty() or board.hop or board.wagon < 0: return 0.0
	var stance = owner_actor.stance_of(scene,track,soldier)
	var at: Vector2 = owner_actor._board_pose(scene,track,soldier).at
	var facing: float = soldier.face if soldier.face != 0 else track.facing
	var points = PackedVector2Array([at])
	if stance.sprite.frame >= 0:
		points = PackedVector2Array()
		for texel in Poses.texels(stance.sprite.family,stance.sprite.frame,track.actor.side): points.append(at+Vector2(facing*texel.x,texel.y))
	var rect: Rect2 = Geometry.wagon(scene,track.roof,board.wagon).rect
	var columns = int(rect.size.x/0.25)+1
	var surface = PackedFloat32Array()
	for column in columns: surface.append(Geometry.drawn_y(scene,track.roof,board.wagon,rect.position.x+column*0.25))
	var gap = INF
	var edge: float = owner_actor._place(scene,track.roof,soldier.cell,owner_actor._offset(track,soldier)).x+board.ladder
	var rail_top = surface[clampi(int((edge-rect.position.x)/0.25),0,columns-1)]-LADDER_GRAB
	var rail_bottom: float = owner_actor._roof_y(scene,track.roof,board.wagon,edge,0.0)+board.height+MANTLE_START
	for point in points:
		gap = minf(gap,owner_actor._body_distance(point,rect,surface))
		if owner_actor.ladder_up(board): gap = minf(gap,Vector2(absf(point.x-edge),maxf(maxf(rail_top-point.y,point.y-rail_bottom),0.0)).length())
		if gap <= 0.0: break
	return gap


# Distance from a point to the filled region under a wagon's roof profile (columns 0.25px apart).
static func _body_distance(owner_actor, point: Vector2, rect: Rect2, surface: PackedFloat32Array) -> float:
	var column = (point.x-rect.position.x)/0.25
	if column >= 0 and column <= surface.size()-1:
		if point.y >= surface[int(column)]: return 0.0
		var best = INF
		for near in range(maxi(0,int(column)-6),mini(surface.size(),int(column)+7)): best = minf(best,point.distance_to(Vector2(rect.position.x+near*0.25,surface[near])))
		return best
	var wall = 0 if column < 0 else surface.size()-1
	var corner = Vector2(rect.position.x+wall*0.25,surface[wall])
	return absf(point.x-corner.x) if point.y >= corner.y else point.distance_to(corner)


# The wagon's own iron: its most common dark, opaque colour (cached per sprite).
static func _iron(owner_actor, scene, roof: int, index: int) -> Color:
	var texture: Texture2D = Geometry.wagon(scene,roof,index).texture
	var key: int = texture.get_rid().get_id()
	if owner_actor._irons.has(key): return owner_actor._irons[key]
	var image = texture.get_image()
	var counts = {}
	for y in range(0,image.get_height(),2):
		for x in range(0,image.get_width(),2):
			var colour = image.get_pixel(x,y)
			if colour.a < 0.9 or colour.s > 0.3 or colour.get_luminance() > 0.3 or colour.get_luminance() < 0.05: continue
			var bucket = Color(snappedf(colour.r,0.04),snappedf(colour.g,0.04),snappedf(colour.b,0.04))
			counts[bucket] = counts.get(bucket,0)+1
	var best = Color("#2a2a30")
	var most = 0
	for bucket in counts:
		if counts[bucket] > most:
			most = counts[bucket]
			best = bucket
	owner_actor._irons[key] = best
	return best


static func _depth(owner_actor, item: Dictionary) -> float:
	return item.get("depth",item.at.y)+(0.5 if item.has("body") and item.body.fall and item.body.t >= item.body.delay else 0.0) # source: authored, half a logical px nearer.


static func _draw_soldier(owner_actor, scene, at: Vector2, track: Dictionary, soldier: Dictionary) -> void:
	var actor: Dictionary = track.actor
	var colour = Color.WHITE.lerp(Color(1,0.5,0.45),soldier.recoil/RECOIL*0.7)
	var facing: float = soldier.face if soldier.face != 0 else track.facing
	if actor.mammoth:
		var state = Beast.state(track,soldier)
		Mammoth.draw(scene,scene.world_transform,actor.side,state.kind,state.motion,state.index,at,facing,state.riders)
		return
	if not soldier.board.is_empty() and soldier.board.t < soldier.board.dismount:
		if soldier.board.t >= 0: Mammoth.draw_dismount(scene,scene.world_transform,actor.side,owner_actor._board_pose(scene,track,soldier).dismount,at,soldier.board.face,colour)
		return # before his turn the howdah's rider layer shows him
	var stance = owner_actor.stance_of(scene,track,soldier)
	var carrying: bool = not soldier.task.is_empty() and not owner_actor.charges.get(soldier.task.key,{"placed":true}).placed
	if stance.sprite.frame >= 0:
		Poses.draw_frame(scene,scene.world_transform,actor.side,at,facing,stance.sprite.family,stance.sprite.frame,colour)
		if carrying and soldier.board.is_empty(): owner_actor._draw_box(scene,at+Vector2(facing*(Poses.BOX_REACH[0]+BOX_HALF),0),false) # carried to where it is set down
		return
	Rig.draw(scene,scene.world_transform,actor.side,at,facing,stance.rig,colour)
	if carrying: # the planter carries the box until he sets it down
		var low = minf(stance.rig.crouch,1.0)
		owner_actor._draw_box(scene,at+Vector2(facing*(2.0+1.5*low),-5.5+3.5*low),false)


# How a trooper is posed: the rig pose and the sprite frame (frame -1: none, the
# rig is drawn). The rig's feet centroid and the sprite's pivot are both the
# soldier's point, and the rig crouch is chosen to match the sprite's height, so
# switching between them moves nothing and changes the height by under a pixel.
static func stance_of(owner_actor, scene, track: Dictionary, soldier: Dictionary) -> Dictionary:
	var climb = 0.0
	var crouch: float = soldier.crouch
	var amp: float = soldier.amp
	var sprite = {"family":Poses.PLANT,"frame":soldier.plant}
	if not soldier.board.is_empty():
		var board = owner_actor._board_pose(scene,track,soldier)
		climb = board.climb
		crouch = board.crouch
		if board.amp >= 0: amp = board.amp
		sprite = {"family":Poses.CLIMB,"frame":board.frame}
	var strike: float = 1.0-soldier.strike/STRIKE if soldier.strike > 0 else 0.0
	var rig = Rig.pose(soldier.phase,amp,0.32*amp*(1.0-climb),crouch,strike,soldier.recoil/RECOIL,climb,soldier.breath)
	return {"rig":rig,"sprite":sprite}


# Sprite of a fall at u of DEATH: [family, frame]; the last frame lands at IMPACT and lies.
static func death_frame(kind: int, u: float) -> Array:
	var family := Poses.FALL_FORWARD if kind == 1 else Poses.FALL_BACK
	return [family,floori(clampf(u/IMPACT,0,1)*(Poses.count(family)-1)+0.5)]


# One rider's death: seated slump (hit frames, bracing frame) on the howdah, then the ballistic fall.
# beast_motion/beast_index: the howdah's frame, which the seated rider follows; pair: the sprite of
# both riders falls together; launched: the howdah frame index he topples from (a dying beast).
static func _draw_rider(owner_actor, scene, at: Vector2, body: Dictionary, which: int, dt: float, beast_motion: int, beast_index: int, pair: bool, colour: Color, launched := 0) -> void:
	var side: int = body.side
	var facing: float = body.facing
	var launch = owner_actor._launch(side,beast_motion,launched,which)
	dt = maxf(dt,0.0) # before his turn he sits, as his first slump frame
	var fall = Beast.rider_fall(dt,launch)
	if fall.stage == 0:
		var motion = Mammoth.HIT if fall.frame < 2 else Mammoth.DEATH
		var index: int = fall.frame if fall.frame < 2 else 0
		Mammoth.draw_seated(scene,scene.world_transform,side,motion,index,which,at,facing,Mammoth.rim_shift(side,beast_motion,beast_index,motion,index),colour)
		return
	var foot = at+Vector2(fall.pos.x*facing,fall.pos.y)
	if fall.stage == 2 and not pair: # one man: the trooper's lying sprite
		Poses.draw_frame(scene,scene.world_transform,side,foot,facing,Poses.FALL_BACK,Poses.count(Poses.FALL_BACK)-1,colour)
		return
	var frame: int = fall.frame+1 if pair else (4 if fall.stage == 2 else 2+mini(fall.frame,1))
	Mammoth.draw_faller(scene,scene.world_transform,side,frame,foot,facing,colour)


static func _draw_body(owner_actor, scene, at: Vector2, body: Dictionary) -> void:
	var fading: float = body.t-(body.delay+body.span+LIE) if body.fall else body.t
	var colour = Color(1,1,1,clampf(1.0-fading/FADE,0,1))
	if body.has("rider"):
		owner_actor._draw_rider(scene,at,body,body.rider,body.t-body.delay,Mammoth.STOP,0,body.pair,colour)
		return
	if body.mammoth: # standing until its turn, then every death frame once, lying till it fades
		var shown = Beast.body_state(body)
		Mammoth.draw(scene,scene.world_transform,body.side,shown.kind,shown.motion,shown.index,at,body.facing,shown.riders,colour)
		if shown.motion != Mammoth.DEATH or shown.pair == 0: return
		for which in ([0,1] if shown.pair == 2 else [1]): # a pair falls as one sprite, drawn with the first
			owner_actor._draw_rider(scene,at,body,which,body.t-body.delay,Mammoth.DEATH,shown.index,shown.pair == 2,colour,shown.launched)
			if shown.pair == 2: break
		return
	if body.fall and body.t >= body.delay:
		var fall = owner_actor.death_frame(body.kind,(body.t-body.delay)/DEATH)
		Poses.draw_frame(scene,scene.world_transform,body.side,at,body.facing,fall[0],fall[1],colour)
		return
	Rig.draw(scene,scene.world_transform,body.side,at,body.facing,owner_actor.body_rig(body),colour)


# A body that has not started falling stands: unhurt (fading) or wounded, waiting
# his turn, crouched to the height of the fall's first frame.
static func body_rig(owner_actor, body: Dictionary) -> Dictionary:
	if not body.fall: return Rig.pose(0,0,0,0,0,0,0,body.breath)
	var first = owner_actor.death_frame(body.kind,0.0)
	return Rig.pose(0,0,0,owner_actor._matched(body.side,Poses.top(first[0],first[1],body.side)),0,0,0,body.breath)


# Rig crouch whose silhouette top equals a sprite's (cached).
static func _matched(owner_actor, side: int, top: float) -> float:
	var key = "%d/%.2f" % [side,top]
	if not owner_actor._matches.has(key): owner_actor._matches[key] = Rig.crouch_for_top(top,side)
	return owner_actor._matches[key]


# Dynamite box: dark crate, iron straps, fuse; a lit fuse sputters.
static func _draw_box(owner_actor, scene, foot: Vector2, lit: bool) -> void:
	var box = Rect2(foot+Vector2(-1.75,-2.5),Vector2(3.5,2.5))
	scene.draw_rect(box.grow(0.25),Color("#140d08"))
	scene.draw_rect(box,Color("#6b4526"))
	scene.draw_rect(Rect2(box.position,Vector2(box.size.x,0.5)),Color("#8c5d34"))
	for x in [0.75,2.5]: scene.draw_rect(Rect2(box.position+Vector2(x,0),Vector2(0.25,box.size.y)),Color("#7d858d"))
	var tip = box.position+Vector2(2.75,-1.25)
	scene.draw_line(box.position+Vector2(2.0,0),tip,Color("#d8cfb4"),0.25)
	if lit:
		var flicker = float((owner_actor._sparks*7)%5)/4.0
		scene.draw_rect(Rect2(tip-Vector2(0.25,0.25),Vector2(0.5,0.5)),Color(1,0.85,0.4).lerp(Color(1,0.45,0.1),flicker))
		if owner_actor._sparks%3 == 0:
			scene.draw_rect(Rect2(tip+Vector2(0.25+flicker*0.5,-0.5-flicker*0.5),Vector2(0.25,0.25)),Color(1,0.95,0.6))
