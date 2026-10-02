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
		[[Rect2(277,1,31,36),Vector2(12.5,35.6)],[Rect2(309,1,29,36),Vector2(13.3,35.6)]],
		[[Rect2(339,1,31,36),Vector2(12.5,35.5)],[Rect2(371,1,29,36),Vector2(13.3,35.6)]]],
	[ # fall_forward
		[[Rect2(401,1,35,47),Vector2(13.9,46.9)],[Rect2(437,1,44,42),Vector2(16.1,42.1)],[Rect2(1,60,48,33),Vector2(21.9,29.0)],[Rect2(50,60,46,23),Vector2(24.4,20.8)],[Rect2(97,60,50,19),Vector2(28.1,14.9)]],
		[[Rect2(148,60,35,47),Vector2(13.9,47.2)],[Rect2(184,60,44,42),Vector2(16.1,42.3)],[Rect2(229,60,48,33),Vector2(22.0,29.0)],[Rect2(278,60,46,23),Vector2(25.1,20.9)],[Rect2(325,60,50,19),Vector2(28.1,14.9)]]],
	[ # fall_back
		[[Rect2(376,60,51,45),Vector2(19.3,46.3)],[Rect2(428,60,32,40),Vector2(16.2,40.2)],[Rect2(461,60,42,29),Vector2(17.8,28.9)],[Rect2(1,108,55,21),Vector2(23.5,16.3)]],
		[[Rect2(57,108,51,45),Vector2(19.2,46.6)],[Rect2(109,108,32,40),Vector2(16.2,40.3)],[Rect2(142,108,42,29),Vector2(17.7,29.3)],[Rect2(185,108,55,21),Vector2(23.6,16.8)]]]
]
# Logical px from each frame's pivot to its front (printed by the builder as EXTENT).
const FRONT := [[5.27,3.46,4.73,4.14,6.37],[4.67,3.87],[5.18,4.45,4.35,5.31,5.39],[5.90,4.02,6.12,6.82]]
# Logical px from the planting frames' pivot to the box's left edge they were drawn beside.
const BOX_REACH := [3.33,3.55]


static func count(family: int) -> int:
	return FRAMES[family][0].size()


# Draws one pose with its pivot at a logical foot point, mirrored about it
# when facing < 0. world maps logical to canvas.
static func draw_frame(canvas: CanvasItem, world: Transform2D, side: int, foot: Vector2, facing: float, family: int, index: int, colour := Color.WHITE) -> void:
	var frame: Array = FRAMES[family][side][clampi(index,0,count(family)-1)]
	canvas.draw_set_transform_matrix(world*Transform2D(0,Vector2(facing/PER,1/PER),0,foot))
	canvas.draw_texture_rect_region(TEXTURE,Rect2(-frame[1],frame[0].size),frame[0],colour)
	canvas.draw_set_transform_matrix(world)


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
