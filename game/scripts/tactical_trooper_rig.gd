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
# Body geometry measured on the standing frame (scale 0.1548 texel/source px): source: f50c3cd:game/scripts/tactical_trooper_rig.gd:22 reports this authored standing-frame measurement; retained verbatim.
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
		"crouch": crouch,
		"hip": Vector2(-2.0*crouch+strike_shape*3.0-recoil*2.0,-HIP+9.0*crouch+bob+1.5*strike_shape),
		"lean": lean+0.5*minf(crouch,1.0)+0.35*strike_shape-0.3*recoil+0.1*climb,
		"thrust": strike_shape*4.0-recoil*1.5,
		"drag": 0.12*amp,
	}


# Where the rig stands, logical px from its foot origin (+x toward his facing):
# the middle of his feet.
static func support(rig: Dictionary) -> Vector2:
	return (rig.feet[0]+rig.feet[1])/2.0/PER


# Height of the rig's silhouette above its feet, logical px (negative up): the
# topmost opaque texel of the torso piece under the pose's lean. Used to pick the
# rig pose that matches a sprite frame's height at a hard switch.
static func top(rig: Dictionary, side: int) -> float:
	var image := TEXTURE.get_image()
	var region: Rect2 = UPPER[side]
	var waist: Vector2 = rig.hip+Vector2(0,HIP-WAIST)+Vector2(rig.thrust,0)
	var turn := Transform2D(rig.lean,waist)
	var best := 0.0
	for y in range(int(region.position.y),int(region.end.y)):
		for x in range(int(region.position.x),int(region.end.x)):
			if image.get_pixel(x,y).a < 0.5: continue
			best = minf(best,(turn*(Vector2(x,y)-region.position-UPPER_PIVOT)).y)
	return best/PER


# The crouch (see pose) at which a standing rig's top reaches `top` (logical px, negative up).
static func crouch_for_top(top_wanted: float, side: int) -> float:
	var low := 0.0
	var high := 2.0
	for step in 24: # bisection: top rises monotonically toward 0 as he crouches
		var middle := (low+high)/2.0
		if top(pose(0,0,0,middle),side) < top_wanted: low = middle # still taller than wanted: crouch more
		else: high = middle
	return (low+high)/2.0


# Draws one trooper at a logical foot point. world maps logical to canvas.
static func draw(canvas: CanvasItem, world: Transform2D, side: int, foot: Vector2, facing: float, rig: Dictionary, colour := Color.WHITE) -> void:
	var base := world*Transform2D(0,Vector2(facing/PER,1/PER),0,foot)
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
	var distance := clampf(reach.length(),0.5,(THIGH+SHIN)*0.999) # source: f50c3cd:game/scripts/tactical_trooper_rig.gd:136; existing reach cap below straight two-bone extension.
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
