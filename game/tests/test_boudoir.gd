extends SceneTree
# requires-native-renderer
# Source: native AudioStreamWAV playback; Dummy mixer leaks measured in cadence review.

# Native input regression for authored room and decoded ROOM book/Kolotov actions.
const Saves = preload("res://scripts/session_saves.gd")
var failures: Array[String] = []
var directory: String
var app


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1440, 900)
	directory = ProjectSettings.globalize_path("res://../.cache/boudoir-%s" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	app = load("res://scripts/main.gd").new()
	app.save_path_override = directory.path_join("view.json")
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	app.set_process(false)
	await process_frame
	await process_frame
	# Atomic save comparisons exclude wall-clock audio advancement in this fixture.
	app.game_audio.set_process(false)
	app._restart_engine()
	await _key(KEY_J)
	_check(app.boudoir.visible and not app._modal.visible, "J opens boudoir from engine room")
	await _capture("room")
	await _inventory()
	await _book()
	await _key(KEY_ESCAPE)
	_check(not app.boudoir.visible, "Esc returns to engine room")
	await _key(KEY_M)
	await _key(KEY_J)
	_check(app.boudoir.visible and not app._modal.visible, "J opens boudoir from map")
	await _key(KEY_M)
	_check(not app.boudoir.visible and app._modal.visible, "M returns to map")
	await _navigation_and_revolver()
	await _events()
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	app.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: boudoir native input, inventory, pause, original panel, save/load and revolver end-game")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _inventory() -> void:
	app.calendar.day = 4
	app.engine.lignite = 1234
	app.session.paused = false
	await _click_art(Vector2(0.24, 0.6))
	var view = app.boudoir.inventory
	_check(view.visible, "click Kolotov opens inventory")
	_check(view.report.day == 4 and view.report.wagon_count == app.wagons.count(), "inventory uses current day and composition")
	_check(view.report.present_contents == app.engine.lignite + app.engine.anthracite, "inventory uses current fuel")
	var before: Dictionary = app.session.snapshot()
	var clock_before: float = app.clock.elapsed_seconds
	app._process(5.0)
	_check(app.session.snapshot() == before and app.clock.elapsed_seconds == clock_before, "inventory blocks simulation without toggling pause")
	await _capture("inventory")
	await _key(KEY_ESCAPE)
	_check(not view.visible and app.boudoir.visible, "Esc closes inventory but keeps room")
	app._process(1.0)
	_check(app.clock.elapsed_seconds > clock_before, "room resumes simulation when inventory closes")
	await _key(KEY_I)
	_check(view.visible, "I opens inventory")
	await _key(KEY_ESCAPE)


func _book() -> void:
	await _click_art(Vector2(0.72, 0.85))
	var book = app.boudoir.book
	_check(book.visible, "click illustrated book opens save prompt")
	var before: Dictionary = app.session.snapshot()
	app._process(5.0)
	_check(app.session.snapshot() == before, "save prompt blocks simulation")
	_check(root.gui_get_focus_owner() == book.name_input, "save prompt focuses name field")
	await _type("trip-123456")
	_check(book.name_input.text == "TRIP1234", "typed name accepts 8 uppercase letters/digits")
	await _capture("book")
	await _key(KEY_ENTER)
	var path := directory.path_join("TRIP1234.SAV")
	_check(FileAccess.file_exists(path) and not book.visible, "Return saves named slot and returns to room")
	app.engine.lignite = 1
	await _key(KEY_ESCAPE)
	await _key(KEY_F6)
	var options = app._boudoir_session.reception
	_check(options.visible, "F6 opens options outside the save book")
	await _click_logical(Vector2(255, 160))
	_check(options.loader.visible and options.loader.loading, "floppy icon opens original load prompt")
	await _type("TRIP1234")
	await _key(KEY_ENTER)
	_check(app.engine.lignite != 1 and not options.visible and app._modal.visible, "load restores saved journey")
	await _key(KEY_F6)
	await _click_logical(Vector2(255, 160))
	await _type("TRIP1234")
	var current := Saves.snapshot(app)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{invalid")
	file.close()
	await _key(KEY_ENTER)
	_check(options.visible and options.loader.visible and Saves.snapshot(app) == current, "corrupt save preserves session and prompt")
	_check(options.loader.status.contains("invalid"), "corrupt save explains error")
	await _key(KEY_F1)
	_check(not options.loader.visible, "F1 cancels load prompt")
	await _click_logical(Vector2(159, 84))
	await _key(KEY_J)
	await _key(KEY_S)
	await _key(KEY_F1)
	_check(not book.visible and app.boudoir.visible, "F1 closes focused save prompt")
	var original_size: Vector2 = app.size
	app.size = Vector2(1024, 768)
	await process_frame
	await _click_art(Vector2(0.24, 0.6))
	_check(app.boudoir.inventory.visible, "hotspots follow resized art")
	await _key(KEY_ESCAPE)
	app.size = original_size


func _navigation_and_revolver() -> void:
	await _key(KEY_J)
	await _key(KEY_ESCAPE)
	await _key(KEY_M)
	var rendered: Array = app.world_view.train_renderer.poses(app.world_view, app.journey, app.world_view.consist, 0)
	_check(rendered.size() == 6, "all six initial vehicles use verified original rails")
	var train_bounds: Rect2 = app.world_view.train_renderer.screen_bounds(app.world_view, app.journey, app.world_view.consist, 0)
	_check(Rect2(Vector2.ZERO, app.world_view.size).encloses(train_bounds), "complete train fits initial map viewport")
	await _capture("map")
	await _click_logical(Vector2(211, 168))
	_check(app._boudoir_session.overview.visible, "detailed map opens overview")
	var overview = app._boudoir_session.overview
	_check(overview.chart.available() and overview.chart.frame != null and overview.plan_texture == null, "authored chart loads without historical RGB")
	_check(overview.chart.geometry.towns.size() == 45 and overview.chart.geometry.dots.size() == 206, "complete measured static chart geometry")
	_check(app._boudoir_session.overview.map_point(Vector2(12, 62)) == Vector2(26, 127), "original whole-world marker coordinates")
	await _capture("overview")
	var discovery_before: Dictionary = app.world_view.discovery.snapshot()
	await _click_logical(Vector2(100, 70))
	_check(app._modal.visible and app.world_view.inspecting_map, "lens opens detailed inspection")
	var inspected_camera: Vector2 = app.world_view.camera_world
	app.world_view.update_train()
	_check(app.world_view.camera_world == inspected_camera, "inspection survives stationary cycle")
	_check(app.world_view.discovery.snapshot() == discovery_before, "inspection does not discover remote track")
	await _click_logical(Vector2(177, 168))
	_check(not app.world_view.inspecting_map, "detailed map icon returns to train")
	await _click_logical(Vector2(211, 168))
	await _click_logical(Vector2(211, 168))
	_check(not app.boudoir.visible and not app._modal.visible and not app._boudoir_session.overview.visible, "map return remembers engine after Esc")
	await _click_logical(Vector2(130, 168))
	_check(app.boudoir.visible, "upper right wagon icon opens boudoir")
	await _click_logical(Vector2(96, 186))
	_check(app._boudoir_session.quarters.visible, "lower left wagon icon opens General Quarters")
	await _capture("quarters")
	await _click_logical(Vector2(96, 168))
	_check(not app._boudoir_session.quarters.visible and not app.boudoir.visible, "locomotive icon returns to engine")
	await _click_logical(Vector2(130, 168))
	await _click_logical(Vector2(177, 168))
	_check(app._modal.visible, "original map icon opens map")
	await _click_logical(Vector2(130, 168))
	var before: Dictionary = app.session.snapshot()
	await _click_art(Vector2(0.50, 0.86))
	var event = app._boudoir_session.event
	_check(event.visible and event.mode == "confirm", "revolver opens original confirmation")
	await _capture("revolver")
	await _click(Vector2(700, 400), MOUSE_BUTTON_RIGHT)
	_check(not event.visible and app.session.snapshot() == before, "right click cancels without ending journey")
	await _click_art(Vector2(0.50, 0.86))
	await _click(Vector2(700, 400))
	_check(event.mode == "epitaph" and app.session.paused, "left click ends game and shows epitaph")
	await _capture("epitaph")
	await _click(Vector2(700, 400))
	_check(event.mode == "earth", "epitaph click continues to Earth screen")
	await _key(KEY_ENTER)
	_check(app._boudoir_session.reception.visible and not event.visible, "Earth returns to options without exiting application")
	await _capture("options")
	await _click_logical(Vector2(159, 84))
	_check(not app._boudoir_session.reception.visible and not app.session.paused, "Start begins fresh playable session")


func _events() -> void:
	# Real first-route obstacle and city fixtures already used by test_playable_trip.
	app._restart_engine()
	await _key(KEY_J)
	var cycles := 0
	while not app.works_dialog.visible and cycles < 20000:
		app.engine.speed = 450
		app._advance_journey()
		app._process(0.0)
		cycles += 1
	_check(app.works_dialog.visible and not app.boudoir.visible, "route works interrupt boudoir visibly")
	app.works_dialog.hide()
	app._restart_engine()
	app.network.repair(Vector2i(83, 67))
	await _key(KEY_J)
	cycles = 0
	while not app._city_panel.visible and cycles < 20000:
		app.engine.speed = 450
		app._advance_journey()
		app._process(0.0)
		cycles += 1
	_check(app._city_panel.visible and not app.boudoir.visible, "station arrival interrupts boudoir visibly")
	app._restart_engine()
	await _key(KEY_J)
	app.engine.heat = 5000
	app.engine.cycle_lignite()
	app.engine.cycle_lignite()
	app._process(1.0)
	_check(app.engine.event_pending and not app.boudoir.visible, "boiler overload returns to visible engine event")


func _key(code: int, unicode_value := 0) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.unicode = unicode_value
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame
	await process_frame


func _type(value: String) -> void:
	for index in value.length():
		await _key(value.to_upper().unicode_at(index), value.unicode_at(index))


func _click_logical(point: Vector2) -> void:
	var bounds: Rect2 = app._boudoir_session.panel.frame_rect()
	await _click(bounds.position + point * bounds.size / Vector2(320, 200))


func _click_art(normalized: Vector2) -> void:
	var bounds: Rect2 = app.boudoir.art_rect()
	await _click(bounds.position + bounds.size * normalized)


func _click_control(control: Control) -> void:
	await process_frame
	await _click(control.get_global_rect().get_center())


func _click(point: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame
	await process_frame


func _capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	RenderingServer.force_draw(false)
	# All screens can contain private YODA/CARTE pixels.
	var path := ProjectSettings.globalize_path("res://../reference-private/boudoir-%s.png" % label)
	_check(root.get_texture().get_image().save_png(path) == OK, "capture " + label)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
