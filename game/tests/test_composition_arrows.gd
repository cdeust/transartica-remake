extends SceneTree
# MIT. Regression from native7167: final thumbnail covers the left arrow.
# Model layout bounds only; root performs native visual/input acceptance.
const PanelScript = preload("res://scripts/original_panel.gd")
const Renderer = preload("res://scripts/train_renderer.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var saved = JSON.parse_string(FileAccess.get_file_as_string("res://../reference-private/validation/reverse-obstacle-approach-earned.json"))
	var wagons = preload("res://scripts/train_wagons.gd").new()
	assert(wagons.restore(saved.wagons))
	var renderer = Renderer.new()
	assert(renderer.load_assets())
	var panel = PanelScript.new()
	root.add_child(panel)
	panel.app={"wagons":wagons,"world_view":{"train_renderer":renderer}}
	var original: Array = wagons.snapshot()
	for count in [13,14]:
		wagons.wagons=original.duplicate(true)
		if count==14: wagons.wagons.append([8,0,0,0]) # Actual source drill type8.
		for extent in [Vector2(1440,900),Vector2(1280,800),Vector2(600,1000)]:
			panel.size=extent
			for first in count:
				panel.ecs_art.first_wagon=first
				var rows: Array = _legacy(panel,renderer) if "--legacy-layout" in OS.get_cmdline_user_args() else panel.composition_layout()
				# Independently decoded source arrow interval, panel-layout evidence.
				var allowed: Rect2=panel.screen_rect(Rect2(14,149,286,9))
				if rows.is_empty(): failures.append("Composition vanished count%d first%d size%s" % [count,first,extent])
				for item in rows:
					if not allowed.encloses(item.bounds): failures.append("Thumbnail covers arrow count%d first%d size%s bounds%s" % [count,first,extent,item.bounds])
	panel.ecs_art.first_wagon=0
	var progressed:=false
	for click in 14:
		var previous: int=panel.ecs_art.first_wagon
		assert(panel.ecs_art.scroll(panel,Vector2(7,153)))
		progressed=progressed or panel.ecs_art.first_wagon>previous
		for item in panel.composition_layout():
			if not panel.composition_window().encloses(item.bounds): failures.append("Actual scroll produces arrow overlap")
	if not progressed: failures.append("Left arrow no longer scrolls long composition")
	for click in 14: assert(panel.ecs_art.scroll(panel,Vector2(312,153)))
	if panel.ecs_art.first_wagon!=0: failures.append("Right arrow fails to return to locomotive")
	panel.app=null
	panel.queue_free()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS:13/14-wagon thumbnails remain between arrows at all scroll offsets and tested resize sizes")
	quit(0 if failures.is_empty() else 1)
func _legacy(panel,renderer) -> Array:
	var result: Array=[]
	var right:=300
	var factor: float=panel.frame_rect().size.x/320.0
	for index in range(panel.ecs_art.first_wagon,panel.app.wagons.count()):
		var wagon: Array=panel.app.wagons.wagons[index]
		var kind: String=preload("res://scripts/train_consist.gd").TYPE_TO_KIND[int(wagon[0])]
		var vehicle: Dictionary=renderer.frame_for(kind)
		var width: int=panel.ecs_art.wagon_width(wagon)
		var scale: float=minf((width-2.0)/vehicle.bounds.size.y,5.0/vehicle.bounds.size.x)*factor
		var center: Vector2=panel.screen_rect(Rect2(right-width/2.0,153.5,0,0)).position
		var transform: Transform2D=renderer.registration(vehicle,center,-PI/2,scale)
		result.append({"bounds":transform*vehicle.bounds})
		right-=width
		if right<14: break
	return result
