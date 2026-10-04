extends SceneTree
# MIT. Source: tasks/validation/common-map-access-20261004.md.
# Real Main/controller prepared UI fixture; no travel or campaign proof.
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var app = load("res://main.tscn").instantiate()
	app.play_startup_intro = false
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/common-map-access/save.json")
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.session.paused = true
	var controller = app._boudoir_session
	var panel = controller.panel
	panel.reference_pixels = false
	var cycles: int = app.engine.cycles
	var reverse: bool = app.journey.reverse
	var brake: bool = app.engine.brake
	for room in ["room", "boudoir", "quarters", "map"]:
		app._open_panel(room)
		await process_frame
		check(panel.visible,"panel visible in " + room)
		check(panel.hotspot_at(panel.screen_rect(Rect2(210,169,1,1)).position)==1,"overall slot active in " + room)
		check(panel.hotspot_at(panel.screen_rect(Rect2(177,169,1,1)).position)==4,"detailed slot active in " + room)
		check(panel.contextual_commands().has(3)==(room=="map"),"reverser retains context in " + room)
		check(panel.contextual_commands().has(5)==(room=="map"),"brake retains context in " + room)
		click(panel,Vector2(210,169))
		check(controller.overview.visible,"overall map opens from " + room)
		check(controller.last_room==room,"return caller captured from " + room)
		click(panel,Vector2(210,169))
		check(not controller.overview.visible and room_visible(app,room),"button returns to " + room)
		click(panel,Vector2(210,169))
		var escape = InputEventKey.new()
		escape.physical_keycode = KEY_ESCAPE
		check(controller.handle_key(escape),"overview handles escape from " + room)
		check(not controller.overview.visible and room_visible(app,room),"escape returns to " + room)
	check(app.session.paused and app.engine.cycles==cycles,"map navigation retains pause and time")
	check(app.journey.reverse==reverse and app.engine.brake==brake,"map navigation retains driving state")
	app.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: shared modern rooms expose both maps and return to caller without changing time/driving state")
	quit(0 if failures.is_empty() else 1)

func room_visible(app,room: String) -> bool:
	var controller = app._boudoir_session
	if room=="map": return app._modal.visible
	if room=="boudoir": return controller.view.visible
	if room=="quarters": return controller.quarters.visible
	return not app._modal.visible and not controller.view.visible and not controller.quarters.visible

func click(panel,point: Vector2) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = panel.screen_rect(Rect2(point,Vector2.ONE)).position
	panel._gui_input(event)

func check(condition: bool,message: String) -> void:
	if not condition: failures.append(message)
