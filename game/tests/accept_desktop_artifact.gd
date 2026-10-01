extends SceneTree

# MIT. Desktop artifact acceptance: dependencies resolve exclusively from res://.
# Source debug is explicitly labelled and cannot produce an artifact PASS.
const WagonTable = preload("res://scripts/train_wagons.gd")
var failures: Array[String] = []
var evidence := ""
var app
var source_debug := false
var report: Dictionary = {}


func _initialize() -> void:
	OS.low_processor_usage_mode = false
	_run.call_deferred()


func check(value: bool, description: String) -> void:
	if not value:
		failures.append(description)
		push_error(description)


func frames() -> void:
	await process_frame
	await process_frame


func key(code: int, unicode_value := 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode_value
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await frames()


func click(control: Control, logical: Vector2, panel := false) -> void:
	var bounds: Rect2 = control.frame_rect() if panel else control.canvas_rect()
	var local := bounds.position + logical * bounds.size / Vector2(320, 200)
	var point: Vector2 = control.get_global_transform_with_canvas() * local
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await frames()


func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(not image.is_empty(), "Native viewport image is nonempty: " + name)
	check(image.save_png(evidence.path_join(name + ".png")) == OK, "Write capture: " + name)


func _run() -> void:
	source_debug = OS.get_environment("TRANSARTICA_ARTIFACT_SOURCE_DEBUG") == "1"
	evidence = OS.get_environment("TRANSARTICA_ARTIFACT_EVIDENCE_DIR")
	check(evidence.is_absolute_path() and "/.cache/" in evidence, "Evidence directory must be an absolute project .cache child")
	check(DisplayServer.get_name() != "headless", "Native desktop renderer required")
	if not source_debug:
		check(not OS.has_feature("editor"), "Exported executable required")
		check(not FileAccess.file_exists("res://tests/accept_desktop_artifact.gd"), "Tests excluded from PCK")
	for filename in ["CARTE.FIC", "villes-decoded.data", "campaign.json", "commerce.json", "startup.json", "audio/manifest.json", "audio/music.json"]:
		check(FileAccess.file_exists("res://private-data/" + filename), "Bundled private dataset: " + filename)
	if not failures.is_empty():
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(evidence)
	var executable := OS.get_executable_path()
	check(not evidence.begins_with(executable.get_base_dir() + "/"), "Captures and saves stay outside application artifact")
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(FileAccess.get_file_as_bytes(executable))
	report = {"mode": "SOURCE-DEBUG" if source_debug else "EXPORTED-MACOS", "executable": executable,
		"executable_sha256": hashing.finish().hex_encode(), "renderer": DisplayServer.get_name()}
	app = load("res://main.tscn").instantiate()
	app.save_path_override = evidence.path_join("session-%s/ARTIFACT.SAV" % OS.get_process_id())
	root.add_child(app)
	app.set_process(false) # Freeze simulation only; all input uses the viewport dispatcher.
	await frames()
	check(app.play_startup_intro, "Bundled main scene enables original boot")
	var intro = app._boot.intro
	check(intro != null and intro.visible, "Actual entry starts exclusive boot screen")
	while intro.tick < intro.TITLE_READY:
		await process_frame
	await capture("boot-title")
	await key(KEY_ENTER)
	while intro.visible:
		await process_frame
	check(app._boudoir_session.reception.visible, "Original boot completion opens OPTIONS")
	app.set_process(false)
	await click(app._boudoir_session.reception,Vector2(159,84))
	check(not app._boudoir_session.reception.visible, "Actual boot START plaque enters engine")
	check(app.world_data.map_bytes == FileAccess.get_file_as_bytes("res://private-data/CARTE.FIC"), "Live map loaded from PCK bytes")
	check(app.world_data.cities.size() == 46, "Original 46-city table loaded")
	check(app.campaign.state.data == JSON.parse_string(FileAccess.get_file_as_string("res://private-data/campaign.json")), "Live campaign loaded from bundled JSON")
	var dataset_hashes: Dictionary = {}
	for filename in ["CARTE.FIC", "villes-decoded.data", "campaign.json", "commerce.json"]:
		dataset_hashes[filename] = FileAccess.get_sha256("res://private-data/" + filename)
	report["bundled_dataset_sha256"] = dataset_hashes
	var panel = app._boudoir_session.panel
	check(panel._texture != null and panel._icon_atlas != null, "Authored HUD textures loaded")
	check(not panel.reference_pixels, "Authored HUD mode active")
	if not source_debug:
		check(not panel.ecs_art.available, "No private YODA rasters in exported HUD")
	await key(KEY_L)
	await key(KEY_A)
	await key(KEY_RIGHT)
	check(app.engine.lignite_rate == 1 and app.engine.anthracite_rate == 1 and app.engine.regulator == 15, "Engine controls via native viewport keys")
	await capture("engine")
	await key(KEY_M)
	check(app._modal.visible and panel.map_context, "Map via native viewport key")
	# Explicit empty-wagon UI fixture, removed by the actual START command below.
	# This is not campaign progression or an earned inventory claim.
	for index in range(12):
		app.wagons.wagons.append([17, 0, 0, 0])
	panel.refresh()
	await click(panel, Vector2(6, 154), true)
	check(panel.ecs_art.first_wagon == 1, "Authored wagon strip scrolls without private YODA raster")
	await capture("map-scroll")
	await click(panel, Vector2(310, 154), true)
	check(panel.ecs_art.first_wagon == 0, "Authored wagon strip scroll returns")
	await key(KEY_F6)
	var reception = app._boudoir_session.reception
	check(reception.visible, "Options via native viewport key")
	await capture("options")
	await click(reception, Vector2(159, 84))
	check(not reception.visible and app.wagons.snapshot() == WagonTable.INITIAL, "START plaque resets UI fixture to original train")
	check(app.engine.regulator == 0 and app.engine.lignite_rate == 0, "START resets engine controls")
	await capture("start")
	await key(KEY_L)
	await key(KEY_RIGHT)
	var engine_before: Dictionary = app.engine.snapshot()
	var train_before: Array = app.wagons.snapshot()
	var journey_before: Dictionary = app.journey.snapshot()
	var campaign_before: Dictionary = app.campaign.state.snapshot()
	var world_before: Dictionary = app.world.snapshot()
	var network_before: Dictionary = app.network.snapshot()
	await key(KEY_F5)
	check(FileAccess.file_exists(app.save_path_override), "F5 writes actual named save outside artifact")
	await key(KEY_RIGHT)
	check(app.engine.regulator != engine_before.regulator, "Actual key changes state before resume")
	await key(KEY_F6)
	await click(reception, Vector2(255, 160))
	check(reception.loader.visible, "LOAD plaque opens actual save book")
	await frames()
	for character in "ARTIFACT":
		await key(character.unicode_at(0), character.unicode_at(0))
	check(reception.loader.name_input.text == "ARTIFACT", "Native key typing reaches save-name LineEdit")
	await key(KEY_ENTER)
	check(not reception.visible, "Save book resumes through actual dispatcher")
	check(app.engine.snapshot() == engine_before, "Engine snapshot restored")
	check(app.wagons.snapshot() == train_before, "Original train snapshot restored")
	check(app.journey.snapshot() == journey_before, "Journey snapshot restored")
	check(app.campaign.state.snapshot() == campaign_before, "Campaign snapshot restored")
	check(app.world.snapshot() == world_before, "World mutations snapshot restored")
	check(app.network.snapshot() == network_before, "Rail network snapshot restored")
	await capture("resumed")
	report["save_path"] = app.save_path_override
	report["save_sha256"] = FileAccess.get_sha256(app.save_path_override)
	report["input_path"] = "Viewport.push_input: engine/map/options/START/F5/LOAD/name/Enter"
	app.queue_free()
	await frames()
	_finish()


func _finish() -> void:
	report["failures"] = failures
	report["passed"] = failures.is_empty()
	if not evidence.is_empty() and DirAccess.dir_exists_absolute(evidence):
		var output := FileAccess.open(evidence.path_join("acceptance.json"), FileAccess.WRITE)
		if output != null:
			output.store_string(JSON.stringify(report, "\t"))
	print(("SOURCE-DEBUG" if source_debug else "EXPORTED-MACOS") + ": " + ("PASS" if failures.is_empty() else "FAIL") + " desktop artifact acceptance")
	quit(0 if failures.is_empty() else 1)
