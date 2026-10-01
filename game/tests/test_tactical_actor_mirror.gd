extends SceneTree
# requires-native-renderer
# MIT. Mirrored actors stay on their foot point: rendered silhouettes of each
# pose facing right and left are reflections about the same column.
const Art = preload("res://scripts/tactical_actor_art.gd")
const SCALE := 8.0 # source: review magnification, logical→screen px
class Probe extends Control:
	var pose := 0
	var facing := 1.0
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color.WHITE)
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE*SCALE)
		Art.new().draw_pose(self,pose,Vector2(40,40),facing)

func _initialize() -> void:
	run.call_deferred()

func span(image: Image) -> Vector2:
	var low := INF
	var high := -INF
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).r < 0.9 or image.get_pixel(x,y).b < 0.9:
				low = minf(low,x)
				high = maxf(high,x+1)
	return Vector2(low,high) # captured pixels; window scaling cancels in the comparison

func run() -> void:
	root.size = Vector2i(640,400)
	var probe := Probe.new()
	probe.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	probe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(probe)
	var failures := []
	for pose in [0,1,2,4,5,6,8,9]:
		var spans := []
		for facing in [1.0,-1.0]:
			probe.pose = pose
			probe.facing = facing
			probe.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image()
			spans.append(span(shot))
		# Foot column = drawn centre (bottom-centre anchor): a mirror keeps the same
		# centre and width; the old in-place flip shifted it by a whole width.
		if absf((spans[0].x+spans[0].y)-(spans[1].x+spans[1].y)) > 2.0 or absf((spans[0].y-spans[0].x)-(spans[1].y-spans[1].x)) > 2.0:
			failures.append("pose %d spans %s / %s" % [pose,spans[0],spans[1]])
	if failures.is_empty(): print("PASS: mirrored actor poses reflect about their foot column")
	else:
		for failure in failures: push_error(failure)
	quit()
