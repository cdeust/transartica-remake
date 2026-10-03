extends SceneTree
# MIT. Regression from the normal-start native resume3Oct, no direct submit().
var app
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	app = load("res://scripts/main.gd").new()
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/native-load-input/view.json")
	root.add_child(app)
	await process_frame
	await process_frame
	app._open_panel("options")
	var reception = app._boudoir_session.reception
	reception.loader.open_book(app._save_path().get_base_dir(),true)
	await process_frame
	await process_frame
	await _key(KEY_L, 76)
	check(reception.loader.name_input.text == "L", "native character enters load name")
	await _key(KEY_BACKSPACE)
	check(reception.loader.name_input.text.is_empty(), "native Backspace edits load name")
	await _key(KEY_L, 76)
	await _key(KEY_ENTER)
	check(reception.loader.status == "BACKUP NOT FOUND", "native Return submits load name")
	await _key(KEY_F1)
	check(not reception.loader.visible, "source F1 still cancels load book")
	app.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: native load name character, Backspace, Return submission and F1 cancellation")
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func _key(code: int, unicode := 0) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.unicode = unicode
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
