extends SceneTree
# requires-native-renderer
# MIT. Native contact sheet of the procedural trooper: eight run phases, rest,
# crouch, strike, recoil and four fall stages, both sides, with a ground line.
const Rig = preload("res://scripts/tactical_trooper_rig.gd")
const OUT := "res://../.cache/rig/poses.png"
class Sheet extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("#d2e9f2"))
		var world := Transform2D(0,Vector2.ONE*6,0,Vector2.ZERO) # 6 screen px per logical px
		var poses := []
		for step in 8: poses.append(Rig.pose(step*PI/4,1.0,0.32))
		poses.append(Rig.pose(0,0,0))
		poses.append(Rig.pose(0,0,0,1.0))
		poses.append(Rig.pose(0,0,0,0,0.5))
		poses.append(Rig.pose(0,0,0,0,0,1.0))
		for stage in [0.25,0.5,0.75,1.0]: poses.append(Rig.pose(0,0,0,0,0,0,stage))
		for side in 2:
			var ground := 22.0+side*24.0
			draw_set_transform_matrix(world)
			draw_line(Vector2(0,ground),Vector2(215,ground),Color("#34414b"),0.15)
			for index in poses.size():
				Rig.draw(self,world,side,Vector2(10+index*12.5,ground),1.0 if side == 0 else -1.0,poses[index])

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1320,300)
	var sheet := Sheet.new()
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(sheet)
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT).get_base_dir())
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT))
	print("PASS: trooper rig contact sheet written")
	quit()
