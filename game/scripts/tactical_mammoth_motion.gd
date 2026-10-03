extends RefCounted
# MIT. How a tactical mammoth group moves and what it shows (presentation only, driven by
# tactical_actor_motion.gd's visual step): the gait, the settle frames after a halt, the
# frame chosen for a hit, a blow or a walk, and how many riders sit. Frames and
# their measurements: tactical_mammoth_poses.gd.
const Mammoth = preload("res://scripts/tactical_mammoth_poses.gd")
const STEP := 1.0/50.0 # source: the shared 50Hz visual step.
# A mammoth walks the 8 frames of its sheet, one frame per measured planted-hoof advance
# (Mammoth.step), so its hooves stay put while a frame shows; it shows the settle frames
# after halting, 4 melee frames per blow, 2 hit frames per loss and all its death frames.
const DEATH := 1.4 # source: authored fall duration, s (8 frames; 5 with a howdah).
const STRIKE := 0.6 # source: authored blow duration, s.
const RECOIL := 0.5 # source: authored hit reaction, s.
const HALT := 0.7 # source: authored, s the settle frames show after the beast halts.
const FLICK := 0.15 # source: authored, s settled before the trunk lowers and the ear flicks.


# A rider killed in the howdah slumps first (hit frames, then the bracing frame), then topples off
# the rim: a ballistic fall from the rim to the ground with a hit impulse that barely lifts him,
# a drift away from the beast, then a slide of under a pixel and lying. A man is ~13 logical px.
const SLUMP := [0.12,0.12,0.2] # source: authored, s on the two hit frames and the bracing frame.
const GRAVITY := 200.0 # source: authored, logical px/s²: a 14-16 px fall takes ~0.45 s.
const LIFT := -24.0 # source: authored, logical px/s (up is negative): a rise of 1.4 px.
const DRIFT := -11.0 # source: authored, logical px/s toward the rear (away from the facing): ~5.6 px over the fall.
const HIPS := 3.0 # source: authored, logical px the toppling body's bottom hangs below the rim.
const BOUNCE := 0.8 # source: authored, logical px of the small bounce on landing.
const SLIDE := 0.8 # source: authored, logical px slid after landing.


# Rider fall at dt seconds after he is hit: launch is the rim point (logical px from the beast's
# pivot, x toward the facing, y up negative). Returns {stage: 0 slump, 1 flying, 2 lying; frame:
# slump index or flight frame 0-2; pos: the body's bottom centre; flight: seconds in flight}.
static func rider_fall(dt: float, launch: Vector2) -> Dictionary:
	var start := launch+Vector2(0,HIPS)
	var slumped := 0.0
	for index in SLUMP.size():
		slumped += SLUMP[index]
		if dt < slumped: return {"stage":0,"frame":index,"pos":start,"flight":0.0}
	var flight := dt-slumped
	var total := (-LIFT+sqrt(LIFT*LIFT-2.0*GRAVITY*start.y))/GRAVITY
	if flight < total:
		var frame := 0 if flight < 0.12 else (1 if flight < 0.3 else 2) # source: authored frame times, s.
		return {"stage":1,"frame":frame,"pos":Vector2(start.x+DRIFT*flight,start.y+LIFT*flight+0.5*GRAVITY*flight*flight),"flight":flight}
	var lying := flight-total
	var settle := minf(lying/0.1,1.0) # source: authored, s the bounce and slide take.
	return {"stage":2,"frame":3,"pos":Vector2(start.x+DRIFT*total-SLIDE*settle,-BOUNCE*sin(PI*settle)),"flight":flight}


# Seconds a rider slumps before he topples.
static func rider_slump() -> float:
	var slumped := 0.0
	for time in SLUMP: slumped += time
	return slumped


# Seconds a rider falls from the hit to landing from this rim point.
static func rider_fall_time(launch: Vector2) -> float:
	var start_y := launch.y+HIPS
	var slumped := 0.0
	for time in SLUMP: slumped += time
	return slumped+(-LIFT+sqrt(LIFT*LIFT-2.0*GRAVITY*start_y))/GRAVITY


# A mammoth's gait: for each move the walk frames needed are planned (Mammoth.plan): the drawn
# body advances by whole planted-hoof steps, only when the frame changes, so a hoof planted in
# one frame is where it was while that frame shows. soldier.lag (cells) is how far the drawn
# body trails the model position (under one step, 0 on arrival); soldier.gait the walk frame
# shown (-1: none). On arrival the beast halts into its settle frames.
static func gait(track: Dictionary, soldier: Dictionary) -> void:
	var kind := Mammoth.variant(track.actor.side,track.actor.count)
	var remaining: float = soldier.cell.distance_to(track.to)*16.0
	if remaining <= 0.001: # source: f50c3cd:game/scripts/tactical_mammoth_motion.gd:72; authored arrival epsilon, unchanged gait fixture.
		if not soldier.walk.is_empty(): soldier.halt = HALT
		else: soldier.halt = maxf(0.0,soldier.halt-STEP)
		soldier.walk = {}
		soldier.gait = -1
		soldier.lag = Vector2.ZERO
		return
	var walk: Dictionary = soldier.walk
	if walk.is_empty() or walk.to != track.to:
		var first: int = (walk.first+walk.passed) if not walk.is_empty() else 0
		var base: Vector2 = soldier.cell-soldier.lag
		var length := base.distance_to(track.to)*16.0
		walk = {"to":track.to,"base":base,"dir":(track.to-base).normalized(),"first":first%8,"passed":0,"kind":kind,"bounds":Mammoth.plan(kind,first,length)}
		soldier.walk = walk
		soldier.halt = 0.0
	var progress: float = walk.base.distance_to(soldier.cell)*16.0
	var passed := 0
	for index in range(1,walk.bounds.size()):
		if walk.bounds[index] <= progress+0.0001: passed = index # source: f50c3cd:game/scripts/tactical_mammoth_motion.gd:90; existing float boundary tolerance for planted gait.
	walk.passed = passed
	soldier.lag = walk.dir*(progress-walk.bounds[passed])/16.0
	soldier.gait = -1 if passed == 0 and soldier.speed <= 0.0 else (walk.first+passed)%8


# What a mammoth shows: the sheet variant of its group, the motion and frame, and how many
# riders sit. A hit beats a blow, a blow beats walking, and a beast that has just halted
# shows its settle frames. Riders: count-1 (the beast is one of the count), two seats; those
# still waiting their turn to step off count as seated.
static func state(track: Dictionary, soldier: Dictionary) -> Dictionary:
	var actor: Dictionary = track.actor
	var seated: int = actor.count+waiting(track) # riders about to step off still sit in the howdah
	var dying := 0 # riders killed this moment keep the howdah on the beast until they have landed
	for body in track.get("dying",[]):
		if body.t < body.delay+body.span: dying = 3
	var state := {"kind":Mammoth.variant(actor.side,seated+dying),"motion":Mammoth.STOP,"index":0,"riders":Mammoth.riders(seated)}
	if soldier.recoil > 0:
		state.motion = Mammoth.HIT
		state.index = 0 if soldier.recoil > soldier.recoil_len*0.5 else 1
	elif soldier.strike > 0:
		state.motion = Mammoth.MELEE
		state.index = mini(3,int((1.0-soldier.strike/soldier.strike_len)*4.0))
	elif soldier.gait >= 0:
		state.motion = Mammoth.WALK
		state.index = soldier.gait
	elif soldier.halt > 0:
		state.index = 1 if HALT-soldier.halt >= FLICK else 0
	return state


# Riders of this beast who are to step off but have not started yet (still sitting).
static func waiting(track: Dictionary) -> int:
	track.leaving = track.leaving.filter(func(soldier): return not soldier.board.is_empty())
	var waiting := 0
	for soldier in track.leaving:
		if soldier.board.t < 0: waiting += 1
	return waiting


# What a dead (or waiting to die) mammoth body shows: the sheet variant of the strength it died with,
# the stop frame until its turn, then every death frame once; the riders it died with (pair: 0 none,
# 1 gunner, 2 both) are drawn by their own falls, so the howdah frame carries none; launched is the
# howdah's frame when they topple.
static func body_state(body: Dictionary) -> Dictionary:
	var kind := Mammoth.variant(body.side,body.count)
	var riders := Mammoth.riders(body.count)
	if body.t < body.delay: return {"kind":kind,"motion":Mammoth.STOP,"index":0,"riders":riders,"pair":0,"launched":0}
	var index := Mammoth.death_index(kind,(body.t-body.delay)/body.span)
	return {"kind":kind,"motion":Mammoth.DEATH,"index":index,"riders":0,"pair":riders,"launched":Mammoth.death_index(kind,rider_slump()/body.span)}
