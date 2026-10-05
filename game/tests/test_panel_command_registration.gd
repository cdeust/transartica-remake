extends SceneTree
# requires-native-renderer
# MIT. Native city32034 artifact: map atlas command must occupy its HUD slot.
var failures: Array[String] = []
class CommandPanel:
	extends 'res://scripts/original_panel.gd'
	func _draw() -> void:
		_draw_map_commands()
func _initialize() -> void:
	OS.low_processor_usage_mode=false
	run.call_deferred()
func capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	var panel=CommandPanel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(panel)
	for viewport in [Vector2i(1440,900),Vector2i(1280,800)]:
		root.size=viewport
		root.content_scale_size=viewport
		for overview in [false,true]:
			panel.overview_context=overview
			panel.hide()
			var before: Image=await capture()
			panel.show()
			panel.queue_redraw()
			var after: Image=await capture()
			var slot: Rect2=panel.screen_rect(panel.MAP_COMMANDS[1])
			var counts:=changed_pixels(before,after,slot)
			var inside:int=counts.inside
			var outside:int=counts.outside
			print('Command registration ',viewport,' overview=',overview,' inside=',inside,' outside=',outside)
			if inside==0 or outside!=0:failures.append('Command pixels must appear only in the real HUD slot')
	panel.queue_free()
	await process_frame
	for failure in failures:push_error(failure)
	if failures.is_empty():print('PASS: map and return icons occupy the scaled HUD slot at both native resolutions')
	quit(0 if failures.is_empty() else 1)

func changed_pixels(before: Image, after: Image, slot: Rect2) -> Dictionary:
	var result:={"inside":0,"outside":0}
	for y in after.get_height():
		for x in after.get_width():
			if before.get_pixel(x,y)!=after.get_pixel(x,y):
				var key:="inside" if slot.has_point(Vector2(x,y)) else "outside"
				result[key]+=1
	return result
