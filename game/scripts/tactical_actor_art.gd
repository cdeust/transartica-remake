extends RefCounted
# MIT. Runtime regions measured on the supplied authored1448x1086 actor master.
# Opaque component bounds: tasks/validation/actor-regions-20260930.log.
# These rectangles are presentation metadata, not original gameplay constants.
const MASTER = preload("res://assets/combat/actors-master.png")
const BOUNDS := {
	0:Rect2(74,98,274,291),1:Rect2(425,108,275,284),
	4:Rect2(68,458,280,290),5:Rect2(427,463,276,286),
	8:Rect2(11,776,410,295),9:Rect2(432,747,393,324)}
# Runner5 and pose9 share row748: runner boot at x617..625, rider helmet
# at x519..529. Separate lower runner boot and upper rider helmet regions
# exclude both neighbours. Separate helmet
# cap and body preserve the whole rider while excluding that neighbouring foot.
const RUNNER_REGIONS := [Rect2(427,463,276,284),Rect2(580,747,100,2)]
const RIDER_REGIONS := [Rect2(505,747,34,8),Rect2(432,755,393,316)]

func pose_for(actor: Dictionary) -> int:
	if actor.mammoth:return 9 if actor.count>1 else 8
	return (0 if actor.side==0 else 4)+(1 if actor.direction!=8 else 0)

func regions_for(pose: int) -> Array:
	if pose==9:return RIDER_REGIONS
	if pose==5:return RUNNER_REGIONS
	return [BOUNDS[pose]]

func draw_actor(canvas: CanvasItem, actor: Dictionary, point: Vector2, _selected := false) -> void:
	var pose := pose_for(actor)
	var bounds: Rect2=BOUNDS[pose]
	# Preserve the scene's existing authored display limits and exact foot anchor.
	var limit := Vector2(28,28) if actor.mammoth else Vector2(12,17)
	var factor := minf(limit.x/bounds.size.x,limit.y/bounds.size.y)
	var origin := point-Vector2(bounds.size.x*factor/2,bounds.size.y*factor)
	for region in regions_for(pose):
		var target := Rect2(origin+(region.position-bounds.position)*factor,region.size*factor)
		canvas.draw_texture_rect_region(MASTER,target,region)
