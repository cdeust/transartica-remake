extends SceneTree
# requires-native-renderer
# MIT. Native side-by-side of the rig's standing soldier with a representative
# frame of every pose sheet (blue then olive), drawn at game scale on one
# ground line, to judge that the sprites match the rig's size.
const Rig = preload("res://scripts/tactical_trooper_rig.gd")
const Poses = preload("res://scripts/tactical_trooper_poses.gd")
const OUT := "res://../tasks/validation/trooper-poses-scale-20261002.png"
class Sheet extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("#d2e9f2"))
		var world := Transform2D(0,Vector2.ONE*6,0,Vector2.ZERO) # 6 screen px per logical px
		for side in 2:
			var ground := 22.0+side*26.0
			draw_set_transform_matrix(world)
			draw_line(Vector2(0,ground),Vector2(190,ground),Color("#34414b"),0.15)
			draw_line(Vector2(0,ground-13),Vector2(190,ground-13),Color("#b05050"),0.25) # the rig's 13 px soldier
			var x := 10.0
			Rig.draw(self,world,side,Vector2(x,ground),1.0,Rig.pose(0,0,0))
			Rig.draw(self,world,side,Vector2(x+14,ground),1.0,Rig.pose(0,0,0,1.2))
			x += 30
			for entry in [[Poses.CLIMB,2],[Poses.CLIMB,4],[Poses.PLANT,0],[Poses.PLANT,1],[Poses.FALL_FORWARD,0],[Poses.FALL_FORWARD,2],[Poses.FALL_FORWARD,4],[Poses.FALL_BACK,0],[Poses.FALL_BACK,1],[Poses.FALL_BACK,3]]:
				Poses.draw_frame(self,world,side,Vector2(x,ground),1.0,entry[0],entry[1])
				x += 16
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1140,330)
	var sheet := Sheet.new()
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(sheet)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT))
	print("PASS: trooper scale comparison written")
	quit()
