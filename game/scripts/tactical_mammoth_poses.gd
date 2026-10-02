extends RefCounted
# MIT. Sprite frames of the tactical mammoths: the bare beast, the beast with its
# howdah (blue or olive) and a rider layer, and the riders' dismount. Frames are
# cut from Codex's generated sheets by res://tools/build_mammoth_poses.gd into
# assets/combat/mammoth-poses.png and listed in tactical_mammoth_frames.gd
# (generated); this file is the runtime side: which frame to show and where.
# Units are atlas texels (PER per logical px); every pivot is the frame's ground
# contact, so a frame is drawn with its pivot on the group's foot point and
# mirrored about it when facing < 0. Authored presentation: the original draws
# no animated mammoths (see FIDELITE.md).
const Frames = preload("res://scripts/tactical_mammoth_frames.gd")
const PER := Frames.PER
enum {WALK, STOP, MELEE, HIT, DEATH}
enum {BARE, PLAYER, ENEMY}
const SEATED := 2 # source: authored; the howdah has two seats, spotter (rear) and gunner (front).


# Sheet variant of a group: bare for a count of 1, else the howdah of its side
# (a bare mammoth is a count of 1; the howdah shows when a group counts more, as
# tactical_actor_art.pose_for did).
static func variant(side: int, count: int) -> int:
	return BARE if count <= 1 else (PLAYER if side == 0 else ENEMY)


# Riders drawn: the mammoth itself is one of the count, the rest ride (merge limit 31),
# two seats.
static func riders(count: int) -> int:
	return clampi(count-1,0,SEATED)


static func count(kind: int, motion: int) -> int:
	return Frames.BODY[kind][motion].size()


static func index_of(kind: int, motion: int, index: int) -> int:
	return clampi(index,0,count(kind,motion)-1)


# Death frame at u in 0..1 of the fall: every frame of the variant's death plays once.
static func death_index(kind: int, u: float) -> int:
	return floori(clampf(u,0,1)*(count(kind,DEATH)-1)+0.5)


# Logical px the body advances from walk frame i to the next while its planted hooves stay put.
static func step(kind: int, frame: int) -> float:
	return Frames.STEP[kind][frame%8]


# Boundaries (cumulative logical px, first 0) of the whole walk frames covering `length`:
# the number of frames whose planted-hoof advances (from frame `first` on) sum nearest the
# length, each advance scaled alike so the last boundary is the length. A move too short
# for one frame is one frame.
static func plan(kind: int, first: int, length: float) -> PackedFloat32Array:
	var sum := 0.0
	var best := 1
	var least := INF
	var frame := 0
	while sum < length+step(kind,first+frame) and frame < 64:
		sum += step(kind,first+frame)
		frame += 1
		if absf(sum-length) < least:
			least = absf(sum-length)
			best = frame
	var total := 0.0
	for index in best: total += step(kind,first+index)
	var scale := length/maxf(total,0.001)
	var bounds := PackedFloat32Array([0.0])
	var run := 0.0
	for index in best:
		run += step(kind,first+index)*scale
		bounds.append(run)
	return bounds


# Draws a body frame (and, for a howdah variant, its rider layer) with the pivot at a
# logical foot point; world maps logical to canvas. `riders` 0..2 is how many sit.
static func draw(canvas: CanvasItem, world: Transform2D, side: int, kind: int, motion: int, index: int, foot: Vector2, facing: float, riders_shown: int, colour := Color.WHITE) -> void:
	var frame: Array = Frames.BODY[kind][motion][index_of(kind,motion,index)]
	canvas.draw_set_transform_matrix(world*Transform2D(0,Vector2(facing/PER,1/PER),0,foot))
	canvas.draw_texture_rect_region(Frames.TEXTURE,Rect2(-frame[1],frame[0].size),frame[0],colour)
	if kind != BARE and riders_shown > 0:
		var parts: Array = Frames.RIDERS[side][motion][index_of(kind,motion,index)]
		for part in _seated(parts,riders_shown):
			canvas.draw_texture_rect_region(Frames.TEXTURE,Rect2(part[1],part[0].size),part[0],colour)
	canvas.draw_set_transform_matrix(world)


# The rider parts to draw: the front one (gunner) alone for one rider, both for two; a merged
# (airborne) sprite is both riders at once.
static func _seated(parts: Array, riders_shown: int) -> Array:
	if parts.size() < 2 or riders_shown >= 2: return parts
	return [parts[-1]]


# Dismount frame k (0 stand on the rim, 1 leg over, 2 hang, 3 drop, 4 land) of a side.
static func draw_dismount(canvas: CanvasItem, world: Transform2D, side: int, k: int, foot: Vector2, facing: float, colour := Color.WHITE) -> void:
	var frame: Array = Frames.DISMOUNT[side][clampi(k,0,4)]
	canvas.draw_set_transform_matrix(world*Transform2D(0,Vector2(facing/PER,1/PER),0,foot))
	canvas.draw_texture_rect_region(Frames.TEXTURE,Rect2(-frame[1],frame[0].size),frame[0],colour)
	canvas.draw_set_transform_matrix(world)


# Height of a dismount frame above its pivot (feet), logical px: how far the hanging
# soldier's hands are over his feet.
static func dismount_height(side: int, k: int) -> float:
	return Frames.DISMOUNT[side][k][1].y/PER


# Seat of rider 0 (spotter, rear) or 1 (gunner, front) on the howdah of the first stop frame:
# logical px from the mammoth's pivot (x toward the facing, y up negative), on the rim.
static func seat(side: int, which: int) -> Vector2:
	var parts: Array = Frames.RIDERS[side][STOP][0]
	var part: Array = parts[clampi(which,0,parts.size()-1)]
	var rim: Vector2 = Frames.SEAT[side][STOP][0]
	return Vector2(part[1].x+part[0].size.x/2.0,rim.y)/PER


# Logical-px bounds of a drawn frame with its riders at foot (for layout checks).
static func bounds(side: int, kind: int, motion: int, index: int, foot: Vector2, facing: float, riders_shown: int) -> Rect2:
	var frame: Array = Frames.BODY[kind][motion][index_of(kind,motion,index)]
	var low: Vector2 = -frame[1]
	var high: Vector2 = frame[0].size-frame[1]
	if kind != BARE and riders_shown > 0:
		for part in _seated(Frames.RIDERS[side][motion][index_of(kind,motion,index)],riders_shown):
			low = Vector2(minf(low.x,part[1].x),minf(low.y,part[1].y))
			high = Vector2(maxf(high.x,part[1].x+part[0].size.x),maxf(high.y,part[1].y+part[0].size.y))
	var xs := [low.x*facing,high.x*facing]
	return Rect2(foot+Vector2(minf(xs[0],xs[1]),low.y)/PER,Vector2(high.x-low.x,high.y-low.y)/PER)


# Planted hoof offsets of a walk frame from its pivot, logical px, toward the facing.
static func feet(kind: int, frame: int) -> Array:
	return Frames.FEET[kind][frame%8]
