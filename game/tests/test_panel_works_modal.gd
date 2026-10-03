extends SceneTree
# MIT. Original works screen blocks simulation/main controls while visible.
# Compare accepted button emissions, independent of rendering or game state.
const PanelScript = preload("res://scripts/original_panel.gd")
var received: Array[int]=[]
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var panel=PanelScript.new()
	root.add_child(panel)
	panel.size=Vector2(1440,900)
	panel.map_context=true
	var works=Control.new()
	root.add_child(works)
	panel.app={"works_dialog":works,"wagons":preload("res://scripts/train_wagons.gd").new()}
	panel.requested.connect(func(code: int): received.append(code))
	var points: Array[Vector2]=[Vector2(24,180),Vector2(96,168),Vector2(130,169),Vector2(96,186),Vector2(132,187),Vector2(177,169),Vector2(210,169),Vector2(177,189),Vector2(210,189),Vector2(7,153),Vector2(312,153)]
	works.show()
	for point in points: click(panel,point)
	var okay: bool=received.is_empty() and panel.ecs_art.first_wagon==0
	if not okay: push_error("Visible works question/report allows underlying panel commands or scrolling")
	works.hide()
	received.clear()
	click(panel,Vector2(24,180))
	okay=okay and received==[2]
	if received!=[2]: push_error("Dismissed works leaves clock control blocked")
	panel.app=null
	panel.queue_free(); works.queue_free()
	if okay: print("PASS: works blocks strip controls and scrolling, normal clock resumes after dismissal")
	quit(0 if okay else 1)
func click(panel,point: Vector2) -> void:
	var event=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
	event.position=panel.screen_rect(Rect2(point,Vector2.ZERO)).position
	panel._gui_input(event)
