extends SceneTree
# MIT. Native raw10361 had665/1232 hero pixels covered by heading UI.
# Prepared geometry regression, not earned campaign or native acceptance.
const Entities=preload("res://scripts/map_entities.gd")
const Renderer=preload("res://scripts/train_renderer.gd")
const Rails=preload("res://scripts/rail_network.gd")
class StraightHistory:
	extends RefCounted
	var direction := Vector2.RIGHT
	var reverse := false
	func sample_behind(distance: float) -> Dictionary:
		return {"ok":true,"position":direction*distance*(1.0 if reverse else -1.0),"heading":6}
var errors: Array[String]=[]
func check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
func _initialize() -> void:
	var renderer=Renderer.new()
	check(renderer.load_assets(),"actual authored frames load")
	var view=preload("res://scripts/travel_world.gd").new()
	view.train_renderer=renderer
	var saved=JSON.parse_string(FileAccess.get_file_as_string("res://../reference-private/validation/reverse-hidden-partial-earned.json"))
	var wagons=preload("res://scripts/train_wagons.gd").new()
	check(wagons.restore(saved.wagons),"earned21 wagon consist loads")
	view.consist.derive_from_wagons(wagons)
	# Exact native10508 sprite bounds reconstructed from its matrix/hero rect.
	var native_bounds=Rect2(Vector2(781.08,182.71),Vector2(74.54,74.55))
	var native_center=Vector2(788.1047,250.2287)
	var native_direction=Vector2(1,-1).normalized()
	var font=ThemeDB.fallback_font
	var extent=font.get_string_size("REVERSE · NORTH-EAST",HORIZONTAL_ALIGNMENT_LEFT,-1,14)
	var old_tip=native_center+native_direction*32
	var old_label=Rect2(old_tip-Vector2(extent.x*0.5,extent.y+24),extent+Vector2(8,6))
	check(old_label.intersects(native_bounds),"exact old native caption masks locomotive")
	var layout=Entities.heading_overlay_layout(native_center,native_direction,extent,native_bounds,Rect2(0,0,1440,670))
	check(not layout.arrow.intersects(native_bounds) and not layout.label.intersects(native_bounds),"native reverse arrow and caption both clear hero")
	var history=StraightHistory.new()
	for viewport_size in [Vector2(320,180),Vector2(640,360),Vector2(1440,670)]:
		view.size=viewport_size
		view.camera_world=Vector2.ZERO
		view.offset=Vector2.ZERO
		# Fit the actual full consist with free HUD space, same authored geometry.
		view.zoom=minf(viewport_size.x,viewport_size.y)/(view.consist.length_world()*view.CELL_PIXELS*2)
		for reverse in [false,true]:
			history.reverse=reverse
			for heading in Rails.DELTAS:
				if heading==5: continue
				history.direction=Vector2(Rails.DELTAS[heading]).normalized()
				var occupied: Rect2=renderer.screen_bounds(view,history,view.consist,0)
				var center: Vector2=view._world_to_screen(Vector2(0.5,0.5))
				var viewport=Rect2(Vector2.ZERO,viewport_size)
				layout=Entities.heading_overlay_layout(center,history.direction,extent,occupied,viewport)
				check(layout.arrow.has_area() and layout.label.has_area(),"cue fits viewport heading%d reverse%s"%[heading,reverse])
				check(viewport.encloses(layout.arrow) and viewport.encloses(layout.label),"cue stays inside fitted viewport")
				check(not layout.arrow.intersects(occupied) and not layout.label.intersects(occupied),"cue cannot cover actual full convoy")
				if not layout.points.is_empty():
					var side=history.direction.orthogonal()
					var arrow_axis=layout.points[1]-(layout.points[0]+layout.points[2])*0.5
					check(arrow_axis.normalized().is_equal_approx(history.direction),"translation keeps actual travel direction")
	layout=Entities.heading_overlay_layout(Vector2(50,50),Vector2.RIGHT,extent,Rect2(0,0,100,100),Rect2(0,0,100,100))
	check(layout.points.is_empty() and not layout.label.has_area(),"fully occupied viewport keeps train unobscured; direction instrument remains")
	view.free()
	for error in errors: push_error(error)
	print("PASS: native overlap regression and eight headings forward/reverse fit arrow and caption outside rendered convoy" if errors.is_empty() else "FAIL: heading overlay geometry")
	quit(0 if errors.is_empty() else 1)
