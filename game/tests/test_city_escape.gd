extends SceneTree
# MIT. Regression: native campaign3Oct, GRANADA salt sale1375.
# Main's general Escape handler shadowed CityScreen.leave_transaction.
# This prepared UI test is separate from the continuous player run.
var app
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	app = load("res://scripts/main.gd").new()
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/city-escape/save.json")
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.session.paused = true
	app._city_panel.open(38,"GRANADA",2,"COMMERCIAL CROSSROADS")
	app._city_panel.start(app.trade.BUY)
	await process_frame
	await key(KEY_ESCAPE)
	check(not app._city_panel.in_transaction(),"Escape leaves city transaction through Main")
	check(app._city_panel.visible,"Escape retains city menu")
	app._city_panel.hide()
	app._modal.show()
	await key(KEY_ESCAPE)
	check(not app._modal.visible,"Escape still closes travel map")
	app.queue_free()
	await process_frame
	for failure in failures:push_error(failure)
	if failures.is_empty():print("PASS: native Main Escape closes commerce transaction and map in their own contexts")
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
