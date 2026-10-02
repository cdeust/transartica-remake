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
		[[Rect2(1,1,26,56),Vector2(5.2,55.6)],[Rect2(28,1,25,39),Vector2(11.1,50.3)],[Rect2(54,1,24,49),Vector2(5.3,49.2)],[Rect2(79,1,24,58),Vector2(7.5,59.6)],[Rect2(104,1,34,47),Vector2(8.0,47.2)]],
		[[Rect2(139,1,26,56),Vector2(5.2,55.6)],[Rect2(166,1,25,38),Vector2(11.4,50.3)],[Rect2(192,1,24,49),Vector2(5.3,48.9)],[Rect2(217,1,24,57),Vector2(7.5,58.1)],[Rect2(242,1,34,47),Vector2(8.0,47.3)]]],
	[ # plant
		[[Rect2(277,1,35,40),Vector2(14.2,40.3)],[Rect2(313,1,33,40),Vector2(15.0,40.3)]],
		[[Rect2(347,1,35,40),Vector2(14.1,40.2)],[Rect2(383,1,33,40),Vector2(15.0,40.3)]]],
	[ # fall_forward
		[[Rect2(417,1,38,52),Vector2(15.4,52.0)],[Rect2(456,1,49,47),Vector2(17.9,46.8)],[Rect2(1,60,53,36),Vector2(24.4,32.2)],[Rect2(55,60,51,26),Vector2(27.1,23.1)],[Rect2(107,60,55,21),Vector2(31.2,16.5)]],
		[[Rect2(163,60,38,52),Vector2(15.4,52.3)],[Rect2(202,60,49,47),Vector2(17.8,46.9)],[Rect2(252,60,53,36),Vector2(24.4,32.2)],[Rect2(306,60,51,26),Vector2(27.8,23.2)],[Rect2(358,60,55,21),Vector2(31.2,16.5)]]],
	[ # fall_back
		[[Rect2(414,60,51,45),Vector2(19.3,46.3)],[Rect2(466,60,32,40),Vector2(16.2,40.2)],[Rect2(1,113,42,29),Vector2(17.8,28.9)],[Rect2(44,113,55,21),Vector2(23.5,16.3)]],
		[[Rect2(100,113,51,45),Vector2(19.2,46.6)],[Rect2(152,113,32,40),Vector2(16.2,40.3)],[Rect2(185,113,42,29),Vector2(17.7,29.3)],[Rect2(228,113,55,21),Vector2(23.6,16.8)]]]
]
# Logical px from each frame's pivot to its front (printed by the builder as EXTENT).
const FRONT := [[5.27,3.46,4.73,4.14,6.37],[5.28,4.37],[5.75,4.94,4.83,5.90,5.98],[5.90,4.02,6.12,6.82]]
# Logical px from the planting frames' pivot to the box's left edge they were drawn beside.
const BOX_REACH := [3.76,4.01]


static func count(family: int) -> int:
	return FRAMES[family][0].size()


# Draws one pose with its pivot at a logical foot point, mirrored about it
# when facing < 0. world maps logical to canvas.
static func draw_frame(canvas: CanvasItem, world: Transform2D, side: int, foot: Vector2, facing: float, family: int, index: int, colour := Color.WHITE) -> void:
	var frame: Array = FRAMES[family][side][clampi(index,0,count(family)-1)]
	canvas.draw_set_transform_matrix(world*Transform2D(0,Vector2(facing/PER,1/PER),0,foot))
	canvas.draw_texture_rect_region(TEXTURE,Rect2(-frame[1],frame[0].size),frame[0],colour)
	canvas.draw_set_transform_matrix(world)


# Height of a frame's top above its pivot, logical px (negative up).
static func top(family: int, index: int, side := 0) -> float:
	return -FRAMES[family][side][clampi(index,0,count(family)-1)][1].y/PER


# Logical px from the pivot to the middle of a frame, toward the facing.
static func centre(family: int, index: int) -> float:
	var frame: Array = FRAMES[family][0][clampi(index,0,count(family)-1)]
	return (frame[0].size.x/2.0-frame[1].x)/PER


# Logical-px bounds of a pose drawn at foot (for layout checks).
static func bounds(foot: Vector2, facing: float, family: int, index: int, side := 0) -> Rect2:
	var frame: Array = FRAMES[family][side][clampi(index,0,count(family)-1)]
	var low: Vector2 = -frame[1]/PER
	var high: Vector2 = (frame[0].size-frame[1])/PER
	var xs := [low.x*facing,high.x*facing]
	return Rect2(foot+Vector2(minf(xs[0],xs[1]),low.y),Vector2(absf(high.x-low.x),high.y-low.y))
