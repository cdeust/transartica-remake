extends SceneTree
# MIT. Default chart is independent of resource192 RGB; original map stays private.
const Overview=preload("res://scripts/ecs_overview.gd")
var errors:Array[String]=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var view=Overview.new()
	view.reference_pixels=false
	view.size=Vector2(1280,596)
	view.journey=preload("res://scripts/train_journey.gd").new()
	view.journey.network=preload("res://scripts/rail_network.gd").new()
	var data=preload("res://scripts/world_data.gd").new()
	check(data.load_from_project(ProjectSettings.globalize_path("res://")),"private bundled geography available")
	view.journey.network.load_bytes(data.map_bytes)
	var before:Dictionary=view.journey.network.snapshot()
	root.add_child(view)
	await process_frame
	check(not view.load_plan("res://private-data/absent-general-plan.json"),"historical RGB deliberately absent")
	check(view.chart.available(),"private static plan vectors load without historical RGB")
	view.authored_available=true # headless has no canvas draw; use same readiness predicate.
	check(view.plan_texture==null and view.chart.frame!=null,"new frame, no reference texture")
	check(view.chart.geometry.towns.size()==45,"all45 measured staticplan towns, not46 live cities")
	check(view.chart.geometry.dots.size()==206,"exact staticplan dotted routes")
	check(view.map_point(Vector2(12,62))==Vector2(26,127),"original marker axes")
	var selected:Array=[]
	view.inspected.connect(func(cell):selected.append(cell))
	var click=InputEventMouseButton.new()
	click.position=Vector2(150,80)*view.size/view.CANVAS
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	view._gui_input(click)
	check(selected==[Vector2i(75,37)],"original lens click offsets retained")
	check(view.journey.network.snapshot()==before,"chart leaves source network immutable")
	view.queue_free()
	await process_frame
	for error in errors:push_error(error)
	if errors.is_empty():print("PASS: authored overview without original RGB, original partial staticplan, marker axes, lens input and immutable private geography")
	quit(0 if errors.is_empty() else 1)
func check(value:bool,message:String)->void:
	if not value:errors.append(message)
