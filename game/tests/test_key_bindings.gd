extends SceneTree

# requires-native-renderer

# MIT. Persisted owner-approved remapping must dispatch actual application input.
const Main = preload("res://scripts/main.gd")
const Bindings = preload("res://scripts/key_bindings.gd")
var failures: Array[String] = []
var app

func _initialize() -> void:
	OS.low_processor_usage_mode = false
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error(description)

func press(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	# source: InputEventKey.unicode supplies printable text to SaveSlots.append_char.
	if code >= KEY_A and code <= KEY_Z: event.unicode = String.chr(code).to_lower().unicode_at(0)
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)

func _run() -> void:
	var directory := ProjectSettings.globalize_path("res://../.cache/keyboard-%d" % OS.get_process_id())
	app = Main.new()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.save_path_override = directory.path_join("VIEW.SAV")
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	var settings = app.get_node("KeyboardSettings")
	check(settings.bindings.assign("map",KEY_K),"Assign and persist map shortcut")
	var reloaded = Bindings.new()
	reloaded.load_settings(directory.path_join("keyboard.cfg"))
	check(reloaded.keys.map == KEY_K,"Fresh settings object reads persisted shortcut")
	check(not reloaded.assign("brake",KEY_K),"Duplicate binding rejects without replacing current keys")
	check(not reloaded.assign("map",KEY_ESCAPE),"Escape remains available to close menus")
	app._open_panel("room")
	press(KEY_M)
	check(not app._modal.visible,"Former shortcut is inert after remapping")
	press(KEY_K)
	check(app._modal.visible,"Remapped shortcut dispatches actual map control")
	check(app.room_controls.key_label("map") == "K","Engine room hints use actual persisted shortcut")
	app._open_panel("boudoir")
	press(KEY_M)
	check(app.boudoir.visible and not app._modal.visible,"Former map key is inert in ordinary boudoir")
	press(KEY_K)
	check(app._modal.visible and not app.boudoir.visible,"Configured map key works in ordinary boudoir")
	check(settings.bindings.assign("save",KEY_ENTER),"Save can bind Enter")
	app.campaign.state.pending={"scene":"urga","messages":[7,8],"reverse":false}
	app.campaign._messages=[7,8]
	app.campaign.page=0
	app.campaign.screen.present("urga",["CONTINUE"])
	press(KEY_ENTER)
	check(app.campaign.page == 1,"Source scene confirmation has priority over remapped Enter save")
	check(not FileAccess.file_exists(directory.path_join("VIEW.SAV")),"Confirming scene does not write a save")
	app.campaign.reset()
	check(settings.bindings.assign("anthracite",KEY_Z),"Move anthracite binding before assigning A save")
	check(settings.bindings.assign("save",KEY_A),"Save can bind A")
	app._open_panel("boudoir")
	app.boudoir.book.open_book(directory)
	await process_frame
	press(KEY_A)
	check(not FileAccess.file_exists(directory.path_join("VIEW.SAV")),"Source book text owns remapped A save")
	check(app.boudoir.book.visible and app.boudoir.book.name_input.text.to_upper() == "A","Typing A reaches source book name input instead of a save shortcut")
	app.boudoir.close_sheet()
	settings.bindings.defaults()
	check(settings.bindings.assign("options",KEY_O),"OPTIONS can bind unused tactical key O")
	var slot: int = app.encounters.enemies.spawn(0,app.encounters.rng)
	app.encounters.pending = slot
	app.encounters.resume_pending()
	app.encounters.manual_scene.set_physics_process(false)
	press(KEY_RIGHT)
	check(app.encounters.manual.velocities[0] == 1,"Default tactical Right still commands train motion")
	press(KEY_SPACE)
	check(app.encounters.manual.velocities[0] == 0,"Default tactical Space still stops train motion")
	press(KEY_F6)
	check(app.encounters.manual_scene.visible and not app._boudoir_session.reception.visible,"Former OPTIONS key is inert in tactical context")
	press(KEY_O)
	check(app._boudoir_session.reception.visible and not app.encounters.manual_scene.visible,"Configured OPTIONS key suspends tactical context")
	app._open_panel("room")
	check(app.encounters.manual_scene.visible,"Tactical state returns after configured OPTIONS")
	check(settings.bindings.assign("options",KEY_P),"Context-conflicting P mapping remains a driving preference")
	var paused: bool = app.encounters.manual_scene.paused
	press(KEY_P)
	check(app.encounters.manual_scene.paused != paused and not app._boudoir_session.reception.visible,"Tactical pause keeps precedence over conflicting OPTIONS mapping")
	app.encounters.reset()
	settings.bindings.defaults()
	settings.open()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_pixel(image.get_width()/2,image.get_height()/2) != image.get_pixel(0,0),"Native settings actually render above background")
	check(image.save_png(ProjectSettings.globalize_path("res://../tasks/validation/keyboard-settings-native.png")) == OK,"Native keyboard settings capture")
	var before: Array = app.wagons.snapshot().duplicate(true)
	settings.selected = "help"
	press(KEY_R)
	check(settings.selected == "help" and settings.bindings.keys.help == KEY_H,"Duplicate key remains rejected during capture")
	check(app.wagons.snapshot() == before,"Settings input does not execute new-game shortcut")
	press(KEY_ESCAPE)
	check(settings.visible and settings.selected.is_empty(),"Escape first cancels key capture")
	press(KEY_ESCAPE)
	check(not settings.visible,"Escape exits settings")
	check(settings.bindings.defaults(),"Restore and persist defaults")
	app.game_audio.reset()
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(directory.path_join("keyboard.cfg"))
	DirAccess.remove_absolute(directory)
	if failures.is_empty():
		print("PASS: persisted keyboard remapping, actual dispatch, duplicate rejection and modal capture")
	quit(0 if failures.is_empty() else 1)
