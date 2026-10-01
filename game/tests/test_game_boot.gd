extends SceneTree

# requires-native-renderer
const Main = preload("res://scripts/main.gd")
var failures: Array[String] = []


func _initialize() -> void:
	OS.low_processor_usage_mode = false
	call_deferred("run")


func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)


func key(code: int) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = code
	Input.parse_input_event(event)


func run() -> void:
	var path := "res://../.cache/boot/never-written.SAV"
	DirAccess.make_dir_recursive_absolute("res://../.cache/boot")
	var fixture = Main.new()
	fixture.save_path_override = path
	root.add_child(fixture)
	await process_frame
	await process_frame
	check(not fixture.play_startup_intro and fixture._boot.intro == null, "programmatic test fixtures retain default optout")
	fixture.queue_free()
	await process_frame
	var scene: PackedScene = load("res://main.tscn")
	var app = scene.instantiate()
	check(not FileAccess.file_exists(path), "isolated boot save path has no user state")
	app.save_path_override = path
	root.add_child(app)
	await process_frame
	await process_frame
	await process_frame
	check(app.play_startup_intro and app._boot.intro != null and app._boot.intro.visible, "actual project scene starts original intro")
	var intro = app._boot.intro
	intro.set_process(false)
	app.engine.regulator = 33
	for code in [KEY_R, KEY_F5, KEY_F6, KEY_M, KEY_B, KEY_SPACE, KEY_ENTER]:
		key(code)
		await process_frame
	check(app.engine.regulator == 33, "restart shortcut cannot escape boot owner")
	check(not FileAccess.file_exists(path), "save shortcut consumed during boot")
	check(app.session.paused and not app.is_processing(), "simulation and event dispatch paused throughout boot")
	check(not app._boudoir_session.reception.visible and intro._exit_tick < 0, "early keys cannot reach options or dismiss first animation")
	app.campaign.present(app.campaign.state._event("urga", [86, 87]))
	while intro.tick < intro.TITLE_READY:
		intro.advance_tick()
	intro.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://../.cache/boot/title-native.png") == OK, "actual boot title native capture")
	intro.set_process(true)
	var completed := [false]
	intro.completed.connect(func(): completed[0] = true, CONNECT_ONE_SHOT)
	key(KEY_ENTER)
	if not completed[0]:
		await intro.completed
	check(not intro.visible and app._boudoir_session.reception.visible, "source title input and wait reaches original OPTIONS")
	check(app.is_processing() and app.session.paused, "host updates resume behind paused OPTIONS")
	key(KEY_ENTER)
	await process_frame
	check(app.campaign.state.pending.is_empty() and app.engine.regulator == 0 and not app._boudoir_session.reception.visible,
		"OPTIONS Enter starts new game instead of advancing restored story underneath")
	app.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: actual main.tscn startup, host input shield, source exit timing and OPTIONS handoff")
	quit(0 if failures.is_empty() else 1)
