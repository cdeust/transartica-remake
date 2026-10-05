extends RefCounted
# MIT. Owner4Oct: a real command cannot move an already occupied branch.
# No latch is inferred from legacy history or a render-only call.
const Rails = preload("res://scripts/rail_network.gd")
static func capture(view, cell: Vector2i) -> void:
	var journey = view.journey
	if journey==null or not journey.reverse: return
	var poses: Array = view.train_renderer.poses(view,journey,view.consist,0)
	# A switch inside the solved prefix is occupied even when later vehicles
	# are still hidden. Do not infer anything beyond the last known rear.
	if poses.is_empty(): return
	var index: int = journey._render_path.points.find(Vector2(cell))
	if index<1 or index+1>=journey._render_path.points.size(): return
	var arc := 0.0
	for step in range(index): arc+=journey._render_path.points[step].distance_to(journey._render_path.points[step+1])
	if arc>=journey._render_cursor or arc<=journey._render_cursor-float(poses[-1].rear_distance): return
	var incoming := 0
	var outgoing := 0
	for heading in Rails.DELTAS:
		if Vector2(Rails.DELTAS[heading])*0.5 == Vector2(cell)-journey._render_path.points[index+1]: incoming=heading
		if Vector2(Rails.DELTAS[heading])*0.5 == journey._render_path.points[index-1]-Vector2(cell): outgoing=heading
	var key := "%d,%d" % [cell.x,cell.y]
	if incoming!=0 and outgoing!=0 and (journey.network.turn(cell,incoming)==outgoing or journey.reverse_switches.get(key,0)==outgoing):
		journey.reverse_switches[key]=outgoing

static func retire(journey) -> void:
	if not journey.reverse:
		journey.reverse_switches.clear()
		return
	for key in journey.reverse_switches.keys():
		var parts: PackedStringArray = key.split(",")
		var center := Vector2(int(parts[0]),int(parts[1]))
		var index: int = journey._render_path.points.find(center)
		if index<1:
			journey.reverse_switches.erase(key)
			continue
		var port_arc := 0.0
		for step in range(index-1): port_arc+=journey._render_path.points[step].distance_to(journey._render_path.points[step+1])
		if journey._render_cursor<port_arc: journey.reverse_switches.erase(key)
