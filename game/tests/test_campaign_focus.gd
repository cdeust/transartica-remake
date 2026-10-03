extends SceneTree
# MIT. Native Rome dialogue1587/1588: Return activated the city button beneath
# the modal again. Direct _unhandled_key_input tests had bypassed GUI focus.
var app
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	app = load("res://scripts/main.gd").new()
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/campaign-focus/save.json")
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.session.paused = true
	app._city_panel.open(21,"ROME",1,"TOWN")
	await process_frame
	var button: Button = app._city_panel._menu.get_child(0)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	check(app.campaign.screen.visible,"real city click opens the notice")
	await key(KEY_ENTER)
	check(not app.campaign.screen.visible,"Return closes notice rather than reactivating underlying city button")
	check(app._city_panel.visible,"notice returns to city without departing")
	check(app.session.paused,"reading notice retains paused city visit")
	app.queue_free()
	await process_frame
	for failure in failures:push_error(failure)
	if failures.is_empty():print("PASS: viewport click and Return own campaign focus and retain city visit")
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, label: String) -> void:
	if not ok:failures.append(label)

func key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
