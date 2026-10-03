extends RefCounted

# source: owner requirement 2026-09-27, complete train initially visible without
# changing zoom during movement. Ten percent framing space is an authored margin.
const VIEWPORT_FILL := 0.9


static func initial_zoom(view) -> float:
	var renderer = view.train_renderer
	if renderer.texels_per_cell <= 0.0 or view.consist.vehicles.is_empty():
		return view._effective_zoom()
	# Use the renderer's actual scale, including any wagon-to-cell ratio. Divide
	# out only camera zoom, so this calibration never changes the rail network.
	var texel_pixels: float = renderer.texel_scale(view) / view._effective_zoom()
	var radius := 0.0
	for kind in view.consist.vehicles:
		var frame: Dictionary = renderer.frame_for(kind)
		if frame.is_empty():
			continue
		var anchor: Vector2 = (frame.front + frame.rear) * 0.5
		var bounds: Rect2 = frame.bounds
		for corner in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
			radius = maxf(radius, anchor.distance_to(corner) * texel_pixels)
	# Triangle inequality: any pair of vehicle centers is at most the complete
	# chain's chord sum apart, for straight and curved arrangements alike. Two
	# maximum anchor-to-alpha radii enclose both endpoint sprites at every heading.
	var chain: float = view.consist.length_world() * renderer.texels_per_cell * texel_pixels
	var diameter := chain + 2.0 * radius
	if diameter <= 0.0:
		return view._effective_zoom()
	return minf(view.size.x, view.size.y) * VIEWPORT_FILL / diameter


static func projected_bounds(view, bounds: Rect2i) -> Rect2:
	var corners := [Vector2(bounds.position), Vector2(bounds.end), Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.position.y)]
	var result := Rect2(view._project(corners[0]), Vector2.ZERO)
	for corner in corners.slice(1):
		result = result.expand(view._project(corner))
	return result


static func center_camera(view, position: Vector2) -> void:
	var middle := position
	if view.journey != null:
		var lag := maxf(0.0, view.journey.distance_travelled() - view._visual_arc) if view._visual_initialized else 0.0
		var sample: Dictionary = view.journey.sample_behind(view.consist.length_world() * view.train_renderer.WAGON_CELL_RATIO * 0.5 + lag)
		if sample.ok:
			middle = sample.position
	view.camera_world = middle + Vector2(0.5, 0.5)
	view.offset = Vector2.ZERO
	view.zoom = view._effective_zoom()


# Fixed camera: recenter only when the train leaves the viewport.
static func keep_train_in_view(view) -> void:
	if view.inspecting_map or view.size.x <= 0.0 or view.size.y <= 0.0 or view.journey == null:
		return
	var lag := maxf(0.0, view.journey.distance_travelled() - view._visual_arc)
	var bounds: Rect2 = _with_next_decision(view,view.train_renderer.screen_bounds(view, view.journey, view.consist, lag))
	var viewport := Rect2(Vector2.ZERO, view.size)
	# Source: FIDELITE.md, constant visible size during travel. A train larger
	# than the viewport must be clipped, never shrunk; frame its nose instead.
	if bounds.size.x > view.size.x or bounds.size.y > view.size.y:
		# Native terminal captures3Oct show that an in-frame contact can still
		# clip the locomotive's alpha bounds. Frame its real rigid sprite.
		var locomotive := {"vehicles":[view.consist.vehicles[0]]}
		var locomotive_bounds: Rect2 = view.train_renderer.screen_bounds(view,view.journey,locomotive,lag)
		var decision_bounds := _with_next_decision(view,locomotive_bounds)
		# At a manually enlarged scale both may not physically fit. Preserve
		# the rigid locomotive rather than change the owner's chosen zoom.
		if decision_bounds.size.x <= view.size.x and decision_bounds.size.y <= view.size.y:
			locomotive_bounds = decision_bounds
		if not viewport.encloses(locomotive_bounds):
			view.offset += view.size*0.5-locomotive_bounds.get_center()
		return
	if viewport.encloses(bounds):
		return
	center_camera(view,view._visual_position)
	bounds = _with_next_decision(view,view.train_renderer.screen_bounds(view, view.journey, view.consist, lag))
	view.offset += view.size * 0.5 - bounds.get_center()


static func _with_next_decision(view, bounds: Rect2) -> Rect2:
	# Native6350: a13-wagon convoy hid switch88,16 until its TIME phase1 turn.
	# TIME0x14bd decides before the cell center; CARTE0x123f clicks that center.
	# Frame the next cell's click point as well as the train, at fixed scale.
	if view.journey.has_method("next_cell"):
		var point: Vector2 = view._world_to_screen(Vector2(view.journey.next_cell())+Vector2(0.5,0.5))
		return bounds.merge(Rect2(point,Vector2.ZERO))
	return bounds
