extends SceneTree
# requires-native-renderer
# MIT. Owner comparison: the howdah's riders head-matched to the trooper rig (as drawn) and
# body-matched (x0.75: seated rider about the trooper's body size), each beside a standing
# trooper, on one image: empty howdah, head-matched riders, body-matched riders, trooper (left to right).
const Mammoth = preload("res://scripts/tactical_mammoth_poses.gd")
const Frames = preload("res://scripts/tactical_mammoth_frames.gd")
const Rig = preload("res://scripts/tactical_trooper_rig.gd")
const OUT := "res://../tasks/validation/mammoth-rider-scale-20261002.png"
const SCALE := 10.0 # source: review magnification, logical to screen px.
class Probe extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("#cfe4f7"))
		var world := Transform2D(0,Vector2.ONE*SCALE,0,Vector2.ZERO)
		var ground := 46.0
		var seat: Vector2 = Frames.SEAT[0][Mammoth.STOP][0]
		for variant in 3: # 0 empty, 1 head-matched, 2 body-matched
			var foot := Vector2(22+variant*38,ground)
			Mammoth.draw(self,world,0,Mammoth.PLAYER,Mammoth.STOP,0,foot,1.0,0)
			if variant > 0:
				var factor := 1.0 if variant == 1 else 0.75
				draw_set_transform_matrix(world*Transform2D(0,Vector2(1/Mammoth.PER,1/Mammoth.PER),0,foot))
				for part in Frames.RIDERS[0][Mammoth.STOP][0]:
					draw_texture_rect_region(Frames.TEXTURE,Rect2(seat+(part[1]-seat)*factor,part[0].size*factor),part[0])
				draw_set_transform_matrix(world)
		Rig.draw(self,world,0,Vector2(122,ground),1.0,Rig.pose(0,0,0))
		draw_set_transform_matrix(world)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280,560)
	var probe := Probe.new()
	probe.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	probe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(probe)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT))
	print("PASS: rider scale comparison written")
	quit()
