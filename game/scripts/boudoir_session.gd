extends RefCounted

# Scene controller; commands and visual structure follow captain-crew/boudoir-layout.md.
const Screen = preload("res://scripts/boudoir_screen.gd")
const Actions = preload("res://scripts/boudoir_actions.gd")
const Inventory = preload("res://scripts/inventory_report.gd")
const Saves = preload("res://scripts/session_saves.gd")
const Slots = preload("res://scripts/save_slots.gd")
var app
var view
var quarters
var panel
var event
var reception
var overview
var last_room := "room"
var city_suspended := false


func attach(owner_app) -> void:
	app = owner_app
	view = _screen(Screen)
	quarters = _screen(preload("res://scripts/general_quarters.gd"))
	overview = _screen(preload("res://scripts/ecs_overview.gd"))
	overview.engine = app.engine
	overview.journey = app.journey
	overview.inspected.connect(_inspect_map)
	overview.hide()
	panel = _screen(preload("res://scripts/original_panel.gd"))
	panel.bind(app)
	app.move_child(panel, view.get_index())
	event = _screen(preload("res://scripts/captain_event.gd"))
	reception = _screen(preload("res://scripts/reception_screen.gd"))
	view.requested.connect(app._open_panel)
	view.action_requested.connect(_action)
	view.book.save_requested.connect(_save)
	quarters.action_requested.connect(_quarters_action)
	panel.requested.connect(_panel_action)
	event.confirmed.connect(_end_journey)
	event.options_requested.connect(func(): app._open_panel("options"))
	reception.start_requested.connect(_new_journey)
	reception.load_requested.connect(_load)
	reception.unavailable_requested.connect(_unavailable)
	app.move_child(event, app.get_child_count() - 1)
	app.session.cycle_completed.connect(_refresh_overview)
	app.resized.connect(_layout)
	_layout()


func _screen(script):
	var control = script.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.add_child(control)
	return control


func _layout() -> void:
	var bounds: Rect2 = panel.screen_rect(Rect2(0, 0, 320, 149))
	for control in [app._modal, overview]:
		control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		control.position = bounds.position
		control.size = bounds.size


func open_panel(name: String) -> bool:
	if name not in ["boudoir", "journal", "quarters", "options", "overview"]:
		return false
	leave()
	match name:
		"boudoir", "journal":
			last_room = "boudoir"
			view.show_room()
		"quarters":
			last_room = "quarters"
			quarters.show()
		"options": reception.open_options(app._save_path().get_base_dir())
		"overview":
			overview.show()
			overview.queue_redraw()
	refresh()
	return true


func leave() -> void:
	view.close_sheet()
	view.hide()
	quarters.hide()
	overview.hide()
	reception.hide()
	event.hide()


func blocks_simulation() -> bool:
	return city_suspended or view.blocks_simulation() or event.visible or reception.visible


func handle_key(input: InputEventKey) -> bool:
	if city_suspended and input.physical_keycode == KEY_ESCAPE:
		leave()
		app._modal.hide()
		app.instruments.hide()
		app._city_panel.show()
		city_suspended = false
		refresh()
		return true
	if event.visible:
		event.handle_key(input.physical_keycode)
	elif reception.visible:
		reception.handle_key(input)
	elif view.visible:
		view.handle_key(input)
	elif quarters.visible or overview.visible:
		if input.physical_keycode == KEY_ESCAPE:
			app._open_panel("room")
		elif input.physical_keycode == KEY_M:
			app._open_panel("map")
		elif input.physical_keycode == KEY_J:
			app._open_panel("boudoir")
	else:
		return false
	refresh()
	return true


func _action(code: int) -> void:
	var action: Dictionary = Actions.dispatch(code, app.stoup)
	match action.get("kind", ""):
		"inventory": view.inventory.show_report(Inventory.build(app.calendar.day, app.engine, app.wagons, app.trade))
		"save_prompt": view.book.open_book(app._save_path().get_base_dir())
		"revolver_prompt": event.prompt_revolver()
		"stoup": _unavailable()
	refresh()


func _panel_action(code: int) -> void:
	# Temporary inspection preserves the visit; Escape returns, EXIT departs.
	if app._city_panel.visible and code in [1, 4, 6, 7, 8]:
		app._city_panel.hide()
		city_suspended = true
	match code:
		1:
			app._open_panel(last_room if overview.visible else "overview" if app._modal.visible else "map")
		2:
			# YODA 0x47c/0x57d, persisted calendar factor; cadence applied by main.
			app.calendar.factor = 3 if app.calendar.factor == 1 else 1
		4:
			app._open_panel("map")
			app.world_view.center_on_train()
		5: app.engine.brake = not app.engine.brake
		6:
			last_room = "room"
			app._open_panel("room")
		7: app._open_panel("quarters")
		8: app._open_panel("boudoir")
		3: _reverse_train()
		9: _unavailable()
	refresh()


func _quarters_action(code: int) -> void:
	# Spy deployment/car menus are not yet integrated; never fabricate an effect.
	if code == 12:
		app._open_panel("overview")
	elif code == 11:
		event.inform(["SPY OPERATIONS ARE NOT YET AVAILABLE"])
	elif code == 13:
		if preload("res://scripts/quarters_actions.gd").cars_count(app.wagons) == 0:
			event.inform(["YOU HAVE NO LINE INSPECTION CARS", "AND YOU CANNOT ACCESS THIS MENU"])
		else:
			_unavailable()
	elif code == 10 and app.stoup.has_pending():
		_unavailable()
	refresh()


func _unavailable() -> void:
	event.inform(["THIS FUNCTION IS NOT YET IMPLEMENTED"])
	refresh()


func _save(slot_name: String) -> void:
	var result: Dictionary = Saves.save(app, Slots.slot_path(app._save_path().get_base_dir(), slot_name))
	if result.ok:
		view.close_sheet()
	else:
		view.book.show_result(result.notice)
	refresh()


func _load(slot_name: String) -> void:
	var result: Dictionary = Saves.restore(app, Slots.slot_path(app._save_path().get_base_dir(), slot_name))
	if not result.ok:
		reception.loader.show_result(result.notice if not result.notice.is_empty() else "BACKUP NOT FOUND")
		return
	leave()
	if not app._city_panel.visible:
		app._open_panel("map")
	refresh()


func _end_journey() -> void:
	# ROOM confirmation ends the current game, not the application or saved files.
	app.session.paused = true
	view.close_sheet()
	event.end_journey()
	refresh()


func _new_journey() -> void:
	app._restart_engine()
	app._open_panel("room")
	refresh()


func refresh() -> void:
	panel.visible = not app.works_dialog.visible
	panel.map_context = app._modal.visible or overview.visible
	panel.overview_context = overview.visible
	panel.refresh()


func present_pending_event() -> void:
	if (view.visible or quarters.visible or overview.visible) and (app._city_panel.visible or app.works_dialog.visible or app.engine.event_pending):
		app._open_panel("room")
	refresh()


func reset() -> void:
	city_suspended = false
	app.world_view.inspecting_map = false
	app.stoup.restore([])
	last_room = "room"
	leave()


func _refresh_overview() -> void:
	# Deferred redraw observes the new position after all cycle callbacks finish.
	if overview.visible:
		overview.queue_redraw()


func _inspect_map(cell: Vector2i) -> void:
	# Original overview message3 selects a detailed-map window, not a train route.
	app._open_panel("map")
	await app.get_tree().process_frame
	app.world_view.following_train = false
	app.world_view.inspecting_map = true
	app.world_view.camera_world = Vector2(cell) + Vector2.ONE * 0.5
	app.world_view.offset = Vector2.ZERO
	app.world_view.queue_redraw()


func _reverse_train() -> void:
	if city_suspended:
		return
	if app.journey.reverse_direction():
		# YODA0x18e3 stops effective speed;0x18d8 releases the brake.
		app.engine.speed = 0
		app.engine.brake = false
		app.world_view._snap_visual_position(app.journey.fractional_position())
		app.world_view.queue_redraw()
		panel.refresh()
