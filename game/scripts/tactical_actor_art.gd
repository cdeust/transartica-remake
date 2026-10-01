extends RefCounted
# MIT. Runtime regions measured on the supplied authored1448x1086 actor master.
# Opaque component bounds: tasks/validation/actor-regions-20260930.log.
# These rectangles are presentation metadata, not original gameplay constants.
const MASTER = preload("res://assets/combat/actors-master.png")
const BOUNDS := {
	0:Rect2(74,98,274,291),1:Rect2(425,108,275,284),
	4:Rect2(68,458,280,290),5:Rect2(427,463,276,286),
	8:Rect2(11,776,410,295),9:Rect2(432,747,393,324),
	# Plant crouch, opaque bounds measured 2 October 2026 (814,169 230x220; 816,531 231x218).
	2:Rect2(813,168,232,222),6:Rect2(815,530,233,220)}
# Runner5 and pose9 share row748: runner boot at x617..625, rider helmet
# at x519..529. Separate lower runner boot and upper rider helmet regions
# exclude both neighbours. Separate helmet
# cap and body preserve the whole rider while excluding that neighbouring foot.
const RUNNER_REGIONS := [Rect2(427,463,276,284),Rect2(580,747,100,2)]
const RIDER_REGIONS := [Rect2(505,747,34,8),Rect2(432,755,393,316)]

# Trooper atlas built by res://tools/build_trooper_atlas.gd from Codex's
# concept sheet (output/imagegen/actors-20261002); PER texels per logical px.
# Per side: stand, run a-d (contact, down, contact, passing), crouch; HEAD is
# the hat column (stable pivot), bottoms sit on the ground line.
const TROOPERS = preload("res://assets/combat/troopers.png")
const PER := 4.0
const TROOPER_CELLS := [
	[Rect2(2,4,36,52),Rect2(53,5,44,51),Rect2(104,10,45,46),Rect2(155,6,43,50),Rect2(206,4,41,52),Rect2(257,21,41,35)],
	[Rect2(2,62,36,52),Rect2(53,62,44,52),Rect2(104,67,46,47),Rect2(155,63,43,51),Rect2(206,61,41,53),Rect2(257,79,41,35)]]
const TROOPER_HEAD := [[14.4,26.1,30.3,24.1,22.6,27.3],[14.6,26.2,30.5,24.2,22.7,27.3]]
const STAND := 0
const CROUCH := 5

func run_frame(phase: float) -> int:
	return 1+int(fposmod(phase,TAU)/(PI/2))%4

# Foot point at the hat column; facing -1 mirrors about that column.
func draw_trooper(canvas: CanvasItem, side: int, frame: int, point: Vector2, facing := 1.0, colour := Color.WHITE) -> void:
	var cell: Rect2 = TROOPER_CELLS[side][frame]
	var target := Rect2(point-Vector2(TROOPER_HEAD[side][frame],cell.size.y)/PER,cell.size/PER)
	if facing < 0:
		target = Rect2(2*point.x-target.end.x,target.position.y,-target.size.x,target.size.y)
	canvas.draw_texture_rect_region(TROOPERS,target,cell,colour)

func pose_for(actor: Dictionary) -> int:
	if actor.mammoth:return 9 if actor.count>1 else 8
	return (0 if actor.side==0 else 4)+(1 if actor.direction!=8 else 0)

func regions_for(pose: int) -> Array:
	if pose==9:return RIDER_REGIONS
	if pose==5:return RUNNER_REGIONS
	return [BOUNDS[pose]]

func draw_actor(canvas: CanvasItem, actor: Dictionary, point: Vector2, _selected := false) -> void:
	draw_pose(canvas,pose_for(actor),point)

# Infantry poses share the standing pose's factor so crouching or running never
# rescales the man; mammoths keep their own limit. Facing -1 mirrors about the foot.
func draw_pose(canvas: CanvasItem, pose: int, point: Vector2, facing := 1.0, colour := Color.WHITE) -> void:
	var bounds: Rect2=BOUNDS[pose]
	var mammoth := pose >= 8
	# Preserve the scene's existing authored display limits and exact foot anchor.
	var limit := Vector2(28,28) if mammoth else Vector2(12,17)
	var scale_bounds: Rect2 = bounds if mammoth else BOUNDS[0 if pose < 4 else 4]
	var factor := minf(limit.x/scale_bounds.size.x,limit.y/scale_bounds.size.y)
	var origin := point-Vector2(bounds.size.x*factor/2,bounds.size.y*factor)
	for region in regions_for(pose):
		var target := Rect2(origin+(region.position-bounds.position)*factor,region.size*factor)
		if facing < 0: # negative width flips in place, so start at the mirrored left edge
			target = Rect2(2*point.x-target.end.x,target.position.y,-target.size.x,target.size.y)
		canvas.draw_texture_rect_region(MASTER,target,region,colour)
