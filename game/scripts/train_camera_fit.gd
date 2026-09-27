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
