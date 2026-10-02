extends RefCounted
# MIT. Procedural cut-out trooper: pieces of Codex's standing trooper
# (assets/combat/trooper-rig.png, built by res://tools/build_trooper_rig.gd),
# two-bone legs solved to planted feet, coat panels following the thighs.
# Units are rig texels (PER per logical px), origin on the ground under the
# soldier, +x toward his facing, +y down. Authored presentation only.
const TEXTURE = preload("res://assets/combat/trooper-rig.png")
const PER := 4.0 # source: rig texels per logical px (atlas lattice).
# Piece rectangles and pivots printed by build_trooper_rig.gd; [blue, olive].
const UPPER := [Rect2(1,1,36,25),Rect2(1,28,36,25)]
const UPPER_PIVOT := Vector2(14.9,24.6) # belt, waist pivot
const BACK := [Rect2(65,1,14,19),Rect2(65,28,14,19)]
const BACK_PIVOT := Vector2(13.3,0.5)
const FRONT := [Rect2(129,1,11,19),Rect2(129,28,12,19)]
const FRONT_PIVOT := Vector2(0.3,0.5)
const BOOT := [Rect2(193,1,9,9),Rect2(193,28,9,9)]
const BOOT_PIVOT := Vector2(3.4,0.2) # top of the shaft
# Cloth under the coat: the coat's own dark tone, deepened (sheet samples
# #2a3654 blue, #68603d olive, x0.7).
const TROUSER := [Color("#1d263b"),Color("#49432b")]
const OUTLINE := Color("#0b0d12")
# Body geometry measured on the standing frame (scale 0.1548 texel/source px):
# belt 179 source px above the sole, boot shaft top 59 px.
const WAIST := 27.7
const HIP := 25.5 # hip joint just below the belt
const SHAFT := 9.1
const THIGH := 9.5 # source: authored; hip to shaft top is 16.4 standing.
const SHIN := 9.5
const STRIDE := 22.0 # source: authored step length (5.5 logical px).
const LIFT := 11.0 # source: authored peak of the recovering foot (heel high, knee drive).
const SINK := 2.5 # source: authored hip drop of a sprinting stance.


# Pose from gait and gesture parameters (all 0..1 unless noted):
# phase (rad, pi per step), amp (stride amplitude), lean (rad, + forward),
# crouch (above 1 kneels), strike, recoil, climb (feet under the body, high
# knees), breath (rad clock).
static func pose(phase: float, amp: float, lean: float, crouch := 0.0, strike := 0.0, recoil := 0.0, climb := 0.0, breath := 0.0) -> Dictionary:
	var feet := []
	var swing := []
	for leg in 2:
		var local := fposmod(phase+PI*leg,TAU)
		var x: float
		var y := 0.0
		var swinging := local >= PI
		if not swinging: # stance: planted, moves back at body speed
			x = STRIDE/2-STRIDE*local/PI
		else: # recovery: heel folds up behind, knee drives through, foot reaches and drops
			var u := (local-PI)/PI
			x = -STRIDE/2+STRIDE*(u*u*(3-2*u)*1.08-0.04*sin(PI*u))
			y = -LIFT*(1.0+0.6*climb)*sin(PI*pow(u,0.8))
		x *= 1.0-0.75*climb
		var rest := 2.0 if leg == 0 else -2.0 # source: authored stance width at rest
		feet.append(Vector2(lerpf(rest,x,amp),y*amp))
		swing.append(swinging and amp > 0.05)
	var strike_shape := sin(PI*strike)
	feet[0].x += strike_shape*5.0 # lunge foot
	var bob := -1.4*cos(2*phase)*amp+SINK*amp+sin(breath)*0.35*(1-amp)
	return {
		"feet": feet, "swing": swing,
		"hip": Vector2(-2.0*crouch+strike_shape*3.0-recoil*2.0,-HIP+9.0*crouch+bob+1.5*strike_shape),
		"lean": lean+0.5*minf(crouch,1.0)+0.35*strike_shape-0.3*recoil+0.1*climb,
		"thrust": strike_shape*4.0-recoil*1.5,
		"tilt": 0.0, "pivot": Vector2.ZERO,
		"drag": 0.12*amp,
	}


# Death falls, t normalised over DEATH seconds; the body ends lying on the
# ground (tilt about a ground pivot). Kinds: 0 struck backward, 1 knees give
# and he pitches forward with legs straightening, 2 staggers a step back and falls.
const DEATH := 0.9 # source: authored fall duration, s.
const IMPACT := 0.85 # source: authored fraction of DEATH when the body lands.
static func dying(kind: int, t: float) -> Dictionary:
	var gravity := func(start: float, span: float) -> float:
		var u := clampf((t-start)/span,0,1)
		return u*u
	var settle := 0.06*sin(PI*clampf((t-IMPACT)/(1.0-IMPACT),0,1)) # small bounce on landing
	var rig: Dictionary
	match kind:
		1:
			var buckle := clampf(t/0.4,0,1)
			var drop: float = gravity.call(0.4,IMPACT-0.4)
			rig = pose(0,0,0.3+0.5*buckle,1.3*buckle*(1.0-drop)+0.1)
			rig.tilt = 1.5*drop-settle
			rig.pivot = Vector2(5,0)
		2:
			var stagger := clampf(t/0.35,0,1)
			rig = pose(0,0,0,0.3*stagger,0,1.0)
			rig.feet[0] = Vector2(2.0-8.0*stagger,-4.0*sin(PI*stagger))
			rig.hip.x -= 4.0*stagger
			rig.tilt = -1.5*gravity.call(0.35,IMPACT-0.35)+settle
			rig.pivot = Vector2(-6,0)
		_:
			var reel := clampf(t/0.3,0,1)
			rig = pose(0,0,0,0.5*reel,0,1.0-0.5*clampf((t-0.3)/0.5,0,1))
			rig.tilt = -1.52*gravity.call(0.3,IMPACT-0.3)+settle
			rig.pivot = Vector2(-3,0)
	return rig


# Draws one trooper at a logical foot point. world maps logical to canvas.
static func draw(canvas: CanvasItem, world: Transform2D, side: int, foot: Vector2, facing: float, rig: Dictionary, colour := Color.WHITE) -> void:
	# Falls tilt the whole body about a ground pivot (heels or knees).
	var base := world*Transform2D(0,Vector2(facing/PER,1/PER),0,foot)*Transform2D(rig.tilt,rig.pivot)*Transform2D(0,-rig.pivot)
	var hip: Vector2 = rig.hip
	var knees := []
	var shafts := []
	var thighs := []
	for leg in 2:
		var target: Vector2 = rig.feet[leg]+Vector2(0,-SHAFT)
		var joint := hip+Vector2(1.0 if leg == 0 else -1.0,0)
		var knee := _knee(joint,target)
		knees.append(knee)
		shafts.append(knee+(target-knee).normalized()*SHIN) # short of an unreachable target
		thighs.append(atan2(knee.x-joint.x,knee.y-joint.y)) # + when the knee leads
	# Panels hang from the belt: the leading thigh opens the front panel, the
	# trailing one the rear panel, and running air drags both back.
	var front: float = -clampf(maxf(thighs[0],thighs[1])*0.35,0,0.45)+rig.drag
	var back: float = clampf(-minf(thighs[0],thighs[1])*0.35,0,0.45)+rig.drag
	var waist := hip+Vector2(0,HIP-WAIST)
	var dim := Color(0.62,0.62,0.66)*colour
	dim.a = colour.a
	# Far leg, rear panel, near leg, front panel, then torso with arms and rifle.
	_leg(canvas,base,side,hip+Vector2(-1,0),knees[1],shafts[1],rig.swing[1],rig.feet[1],dim)
	_piece(canvas,base,BACK[side],BACK_PIVOT,waist,back,colour)
	_leg(canvas,base,side,hip+Vector2(1,0),knees[0],shafts[0],rig.swing[0],rig.feet[0],colour)
	_piece(canvas,base,FRONT[side],FRONT_PIVOT,waist,front,colour)
	if thighs[0] > 0.35: # driving knee clears the coat: shin and boot in front of it
		_leg(canvas,base,side,knees[0],knees[0],shafts[0],rig.swing[0],rig.feet[0],colour)
	_piece(canvas,base,UPPER[side],UPPER_PIVOT,waist+Vector2(rig.thrust,0),rig.lean,colour)
	canvas.draw_set_transform_matrix(world)


static func _knee(hip: Vector2, target: Vector2) -> Vector2:
	var reach := target-hip
	var distance := clampf(reach.length(),0.5,(THIGH+SHIN)*0.999)
	var bend := acos(clampf((THIGH*THIGH+distance*distance-SHIN*SHIN)/(2*THIGH*distance),-1,1))
	return hip+Vector2.from_angle(reach.angle()-bend)*THIGH # knee toward +x


static func _leg(canvas: CanvasItem, base: Transform2D, side: int, hip: Vector2, knee: Vector2, shaft: Vector2, swinging: bool, foot: Vector2, colour: Color) -> void:
	canvas.draw_set_transform_matrix(base)
	var cloth: Color = TROUSER[side]*colour
	cloth.a = colour.a
	var edge := OUTLINE
	edge.a = colour.a
	canvas.draw_line(hip,knee,edge,6.0)
	canvas.draw_line(knee,shaft,edge,5.0)
	canvas.draw_line(hip,knee,cloth,4.5)
	canvas.draw_line(knee,shaft,cloth,3.5)
	# Toe drops through the push-off and swing, flat when planted.
	var toe := 0.0
	if swinging: toe = 0.45*clampf(-foot.y/LIFT,0,1)
	_piece(canvas,base,BOOT[side],BOOT_PIVOT,shaft,toe,colour)


static func _piece(canvas: CanvasItem, base: Transform2D, region: Rect2, pivot: Vector2, at: Vector2, angle: float, colour: Color) -> void:
	canvas.draw_set_transform_matrix(base*Transform2D(angle,at))
	canvas.draw_texture_rect_region(TEXTURE,Rect2(-pivot,region.size),region,colour)
