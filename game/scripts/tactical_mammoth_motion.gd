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


# A mammoth's gait: for each move the walk frames needed are planned (Mammoth.plan): the drawn
# body advances by whole planted-hoof steps, only when the frame changes, so a hoof planted in
# one frame is where it was while that frame shows. soldier.lag (cells) is how far the drawn
# body trails the model position (under one step, 0 on arrival); soldier.gait the walk frame
# shown (-1: none). On arrival the beast halts into its settle frames.
static func gait(track: Dictionary, soldier: Dictionary) -> void:
	var kind := Mammoth.variant(track.actor.side,track.actor.count)
	var remaining: float = soldier.cell.distance_to(track.to)*16.0
	if remaining <= 0.001:
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
		if walk.bounds[index] <= progress+0.0001: passed = index
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
	var state := {"kind":Mammoth.variant(actor.side,seated),"motion":Mammoth.STOP,"index":0,"riders":Mammoth.riders(seated)}
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
