extends RefCounted
# MIT. Whole-body trooper poses the cut-out rig cannot do: climbing a wagon
# ladder and mantling, kneeling to light a charge, and two deaths. Frames are
# cut from Codex's generated sheets by res://tools/build_trooper_poses.gd into
# assets/combat/trooper-poses.png; one scale per sheet, so a soldier stands
# 13 logical px tall as the rig's does. Units are atlas texels (PER per logical
# px); each frame's pivot sits on its sheet's ground line, x on the feet (the
# plant frames: the box's left edge, the game draws the charge itself).
const TEXTURE = preload("res://assets/combat/trooper-poses.png")
const PER := 4.0 # source: texels per logical px, as the rig.
enum {CLIMB, PLANT, FALL_FORWARD, FALL_BACK}
# Frames printed by the builder: FRAMES[family][side] = [[Rect2, pivot], ...];
# climb 0-3 rungs, 4 mantle; plant 0 kneel and set, 1 light; falls in order.
const FRAMES := [
	[ # climb
		[[Rect2(1,1,28,60),Vector2(13.6,59.1)],[Rect2(30,1,27,41),Vector2(13.0,53.4)],[Rect2(58,1,26,52),Vector2(12.0,52.3)],[Rect2(85,1,26,61),Vector2(7.4,63.3)],[Rect2(112,1,36,50),Vector2(14.0,51.1)]],
		[[Rect2(149,1,28,60),Vector2(13.6,59.1)],[Rect2(178,1,27,41),Vector2(13.0,53.4)],[Rect2(206,1,26,52),Vector2(12.0,52.0)],[Rect2(233,1,26,61),Vector2(7.4,61.7)],[Rect2(260,1,36,50),Vector2(14.0,51.2)]]],
	[ # plant
		[[Rect2(297,1,36,41),Vector2(29.5,40.7)],[Rect2(334,1,33,41),Vector2(31.4,40.7)]],
		[[Rect2(368,1,36,41),Vector2(29.5,40.6)],[Rect2(405,1,33,41),Vector2(31.4,40.6)]]],
	[ # fall_forward
		[[Rect2(439,1,39,52),Vector2(15.1,52.2)],[Rect2(1,63,49,47),Vector2(10.7,46.9)],[Rect2(51,63,53,37),Vector2(7.7,32.3)],[Rect2(105,63,51,26),Vector2(6.4,23.1)],[Rect2(157,63,55,21),Vector2(5.7,16.6)]],
		[[Rect2(213,63,39,52),Vector2(15.1,52.5)],[Rect2(253,63,49,47),Vector2(10.7,47.1)],[Rect2(303,63,53,37),Vector2(7.7,32.3)],[Rect2(357,63,51,26),Vector2(6.4,23.3)],[Rect2(409,63,55,21),Vector2(5.7,16.6)]]],
	[ # fall_back
		[[Rect2(1,116,58,51),Vector2(33.0,52.4)],[Rect2(60,116,37,45),Vector2(22.4,45.4)],[Rect2(98,116,48,33),Vector2(23.9,32.7)],[Rect2(147,116,62,24),Vector2(48.4,18.5)]],
		[[Rect2(210,116,58,51),Vector2(33.0,52.7)],[Rect2(269,116,37,46),Vector2(22.4,45.6)],[Rect2(307,116,48,33),Vector2(23.9,33.1)],[Rect2(356,116,62,23),Vector2(48.4,19.0)]]]
]


static func count(family: int) -> int:
	return FRAMES[family][0].size()


# Draws one pose with its pivot at a logical foot point, mirrored about it
# when facing < 0. world maps logical to canvas.
static func draw_frame(canvas: CanvasItem, world: Transform2D, side: int, foot: Vector2, facing: float, family: int, index: int, colour := Color.WHITE) -> void:
	var frame: Array = FRAMES[family][side][clampi(index,0,count(family)-1)]
	canvas.draw_set_transform_matrix(world*Transform2D(0,Vector2(facing/PER,1/PER),0,foot))
	canvas.draw_texture_rect_region(TEXTURE,Rect2(-frame[1],frame[0].size),frame[0],colour)
	canvas.draw_set_transform_matrix(world)


# Logical-px bounds of a pose drawn at foot (for layout checks).
static func bounds(foot: Vector2, facing: float, family: int, index: int, side := 0) -> Rect2:
	var frame: Array = FRAMES[family][side][clampi(index,0,count(family)-1)]
	var low: Vector2 = -frame[1]/PER
	var high: Vector2 = (frame[0].size-frame[1])/PER
	var xs := [low.x*facing,high.x*facing]
	return Rect2(foot+Vector2(minf(xs[0],xs[1]),low.y),Vector2(absf(high.x-low.x),high.y-low.y))
