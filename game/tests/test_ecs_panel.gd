extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var app = load("res://scripts/main.gd").new()
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/panel-test.json")
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	app.set_process(false)
	await process_frame
	await process_frame
	app._restart_engine()
	var panel = app._boudoir_session.panel
	_check(panel.ecs_art.available, "private original YODA resources loaded")
	_check(panel.ecs_art.textures.size() > 80, "original clock, wagon and map sprites decoded")
	app._open_panel("map")
	await process_frame
	panel.refresh()
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.cache/ecs-panel-native.png"))
	for value in range(12):
		app.wagons.wagons.append([17, 0, 0, 0])
	_check(panel.ecs_art.scroll(panel, Vector2(6, 154)) and panel.ecs_art.first_wagon == 1, "composition left arrow scrolls long train")
	_check(panel.ecs_art.scroll(panel, Vector2(310, 154)) and panel.ecs_art.first_wagon == 0, "composition right arrow returns")
	_check(not panel.ecs_art.scroll(panel, Vector2(100, 154)), "strip body does not invent a wagon action")
	_check(not app.world_view.discovery_enabled, "fixed towns and track are not hidden by preview fog")
	for city in app.world_data.cities:
		_check(app.world_view._city_is_visible(city), "fixed city visible before visit")
	app.engine.speed = 100
	var initial_heading: int = app.journey.heading
	var initial_front: Vector2 = app.journey.fractional_position()
	panel.activate(3)
	_check(app.journey.reverse and app.journey.heading == 10 - initial_heading and app.engine.speed == 0 and not app.engine.brake, "HUD wheel reverses traction and stops speed")
	_check(app.journey.fractional_position().distance_to(initial_front) < 0.001, "HUD reverse does not teleport locomotive")
	panel.activate(3)
	_check(not app.journey.reverse, "HUD wheel restores forward traction")
	var saves = preload("res://scripts/session_saves.gd")
	var saved_path: String = app.save_path_override
	_check(saves.save(app, saved_path).ok, "save travel before city inspection")
	app._open_city(24)
	var position: Vector2i = app.journey.position
	app._boudoir_session._panel_action(1)
	_check(not app._city_panel.visible and app._boudoir_session.city_suspended, "HUD map temporarily hides city")
	_check(app._boudoir_session.blocks_simulation(), "inspection cannot resume travel")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	app._unhandled_key_input(escape)
	_check(app._city_panel.visible and app.journey.position == position, "Escape restores same visit without departing")
	app._boudoir_session._panel_action(6)
	_check(app._boudoir_session.city_suspended, "second inspection active")
	_check(saves.restore(app, saved_path).ok and not app._boudoir_session.city_suspended, "successful load clears suspended visit")
	DirAccess.remove_absolute(saved_path)
	app.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty(): print("PASS: original private HUD resources, live composition scrolling and fixed-city visibility")
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
