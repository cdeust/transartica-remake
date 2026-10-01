extends RefCounted
# MIT. Presentation motion for tactical actors, keyed by actor id: glides between
# the source cells, stride bob, facing, plant crouch, melee hits and removal fade.
# Reads the combat model only, on the shared50Hz visual step; never writes it.
# Authored presentation: the original draws field actors as map tiles
# (WDECOR cputmap98) and roof actors as sprites10+cell (0x5126); its facing and
# in-between motion are not decoded, so none of this claims original behaviour.
const Geometry = preload("res://scripts/tactical_effects_geometry.gd")
const STEP := 1.0/50.0
const FADE := 0.4 # source: authored removal fade, s.
const HIT := 0.3 # source: authored melee hit flash, s.
const CROUCH := 0.9 # source: authored plant crouch, s.
const LUNGE := 0.2 # source: authored melee lunge, s.
const REACH := 3.0 # source: authored lunge distance, logical px.
const STRIDES := 2.0 # source: authored strides per16px cell.
var tracks := {}
var _melees := []
var _charges := {}


func clear() -> void:
	tracks.clear()
	_melees.clear()
	_charges.clear()


func melee(event: Dictionary) -> void:
	_melees.append(event)


# Visual seconds the model takes for one cell step of this actor:
# a field pass scans7*columns cells at max(columns/4,40) per tick (0x0244,1389);
# player infantry steps every2 passes, enemy every4, mammoths twice as often
# (0x21dc); roof groups step on every other pass (0x1bd6).
static func span(state, actor: Dictionary, pace: float) -> float:
	var pass_ticks: float = 7.0*state.columns/maxi(state.columns/4,40)
	var period := 2
	if actor.roof < 0:
		period = (2 if actor.mammoth else 4) if actor.side == 1 else (1 if actor.mammoth else 2)
	return period*pass_ticks*state.STEP_SECONDS/pace


func step(scene) -> void:
	var state = scene.state
	var hit_this_step := not _melees.is_empty()
	var seen := {}
	for actor in state.actors:
		seen[actor.id] = true
		var cell := Vector2(actor.x,actor.y)
		var track := _track(actor)
		# Boarding, restore, split/merge: unrelated positions snap instead of sliding.
		if actor.roof != track.roof or track.to.distance_to(cell) > 1.5:
			track.from = cell
			track.to = cell
			track.t = 1.0
			track.roof = actor.roof
		elif cell != track.to:
			var shown := shown_cell(track)
			track.from = shown
			track.to = cell
			track.t = 0.0
			track.span = span(state,actor,scene.pace)
			var dx: float = (cell.x-shown.x)*(-1.0 if actor.roof >= 0 else 1.0) # roof slots run right→left
			if absf(dx) > 0.01: track.facing = signf(dx)
		if track.t < 1.0:
			var before := shown_cell(track)
			track.t = minf(1.0,track.t+STEP/track.span)
			track.phase += before.distance_to(shown_cell(track))*STRIDES*PI
		elif _mid_stride(track): # finish the stride on a foot plant
			var plant := ceilf(track.phase/PI-0.001)*PI
			track.phase = plant if plant-track.phase <= STEP*TAU else track.phase+STEP*TAU
		if actor.count < track.count and hit_this_step:
			track.hit = HIT
		track.count = actor.count
		_decay(track)
	for id in tracks.keys():
		if seen.has(id): continue
		var track: Dictionary = tracks[id]
		if track.fade < 0:
			track.fade = FADE
			if hit_this_step: track.hit = HIT
		track.fade -= STEP
		_decay(track)
		if track.fade <= 0: tracks.erase(id)
	for event in _melees: _lunge(event)
	_melees.clear()
	_plants(state)


func _track(actor: Dictionary) -> Dictionary:
	if not tracks.has(actor.id):
		var cell := Vector2(actor.x,actor.y)
		tracks[actor.id] = {"from":cell,"to":cell,"t":1.0,"span":1.0,"roof":actor.roof,"phase":0.0,
			"facing":1.0,"count":actor.count,"hit":0.0,"crouch":0.0,"lunge":0.0,"aim":Vector2.ZERO,"fade":-1.0}
	var track: Dictionary = tracks[actor.id]
	track.actor = actor
	return track


func _decay(track: Dictionary) -> void:
	track.hit = maxf(0.0,track.hit-STEP)
	track.crouch = maxf(0.0,track.crouch-STEP)
	track.lunge = maxf(0.0,track.lunge-STEP)


# WDECOR0x2679 melee reports the attacker's cell; it lunges at the nearest enemy.
func _lunge(event: Dictionary) -> void:
	var attacker = null
	for track in tracks.values():
		var actor: Dictionary = track.actor
		if actor.x == event.x and actor.y == event.y and track.fade < 0:
			attacker = track
	if attacker == null: return
	var best = null
	for track in tracks.values():
		var other: Dictionary = track.actor
		if other.side == attacker.actor.side or other.roof != attacker.actor.roof: continue
		if best == null or shown_cell(track).distance_to(attacker.to) < shown_cell(best).distance_to(attacker.to):
			best = track
	if best == null: return
	var delta: Vector2 = shown_cell(best)-attacker.to
	# Screen axes: field y grows upward, roof slots grow leftward.
	var screen := Vector2(-delta.x,0) if attacker.actor.roof >= 0 else Vector2(delta.x,-delta.y)
	if screen.length() < 0.01: return
	attacker.aim = screen.normalized()
	attacker.lunge = LUNGE
	if absf(screen.x) > 0.01: attacker.facing = signf(screen.x)


# A new charge (0x1c73 enemy, 0x4674 player) crouches the planting group.
func _plants(state) -> void:
	var current := {}
	for charge in state.charges:
		var key := "%d/%d" % [charge.side,charge.slot]
		current[key] = true
		if _charges.has(key): continue
		var planter = null
		for track in tracks.values():
			var actor: Dictionary = track.actor
			if track.fade >= 0 or actor.side != charge.owner or actor.roof != charge.side: continue
			if absi(actor.x-charge.slot) <= 2 and (planter == null or absi(actor.x-charge.slot) < absi(planter.actor.x-charge.slot)):
				planter = track
		if planter != null:
			planter.crouch = CROUCH
			planter.facing = signf(planter.actor.x-charge.slot) if planter.actor.x != charge.slot else planter.facing
	_charges = current


static func shown_cell(track: Dictionary) -> Vector2:
	# Linear: consecutive cell steps join into one steady walk, no stop-and-go.
	return track.from.lerp(track.to,track.t)


static func _mid_stride(track: Dictionary) -> bool:
	var rest := fposmod(track.phase,PI)
	return rest > 0.001 and rest < PI-0.001


func moving(track: Dictionary) -> bool:
	return track.t < 1.0 or _mid_stride(track)


# Logical foot point of an actor as currently shown (drawing and clicks).
func point(scene, actor: Dictionary) -> Vector2:
	var track: Dictionary = tracks.get(actor.id,{})
	var cell := shown_cell(track) if not track.is_empty() and track.roof == actor.roof else Vector2(actor.x,actor.y)
	var foot: Vector2 = Geometry.roof_point_at(scene,actor.roof,cell.x) if actor.roof >= 0 else scene._field_point(cell.x,cell.y)
	if not track.is_empty() and track.lunge > 0:
		foot += track.aim*REACH*sin(PI*track.lunge/LUNGE)
	return foot


func draw(scene, art) -> void:
	for actor in scene.state.actors: _track(actor) # drawable before the first visual step
	for track in tracks.values():
		var actor: Dictionary = track.actor
		var foot := point(scene,actor)
		var colour := Color.WHITE
		if track.hit > 0: colour = colour.lerp(Color(1,0.42,0.36),track.hit/HIT)
		if track.fade >= 0: colour.a = track.fade/FADE
		if actor.mammoth:
			var bob := -absf(sin(track.phase))*0.5 if moving(track) else 0.0 # source: authored stride lift, logical px.
			art.draw_pose(scene,art.pose_for(actor),foot+Vector2(0,bob),track.facing,colour)
			continue
		var frame: int = art.STAND
		if track.crouch > 0: frame = art.CROUCH
		elif moving(track): frame = art.run_frame(track.phase)
		art.draw_trooper(scene,actor.side,frame,foot,track.facing,colour)
