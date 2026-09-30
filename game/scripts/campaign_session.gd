extends RefCounted

# MIT. UI owner; source-supported state changes are isolated in CampaignState.
const State = preload("res://scripts/campaign_state.gd")
const Screen = preload("res://scripts/campaign_screen.gd")
var state = State.new()
var app
var screen
var page := 0
var selection := ""
var crew_menu := ""
var _messages: Array = []
var _notice := false
var _return_room := "quarters"
var _car_missile := false


func attach(owner_app) -> void:
	app = owner_app
	state.load_data()
	screen = Screen.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.add_child(screen)
	screen.continued.connect(_continue)
	screen.code_submitted.connect(_submit_code)
	screen.answered.connect(_answer)
	screen.menu_selected.connect(_menu_choice)


func before_entry(cell: Vector2i) -> bool:
	var event: Dictionary = state.prepare_entry(cell, app.journey.heading, app.wagons, app.network)
	if event.is_empty():
		return false
	present(event)
	return true


func station(index: int) -> bool:
	var event: Dictionary = state.station(index, app.network)
	if event.is_empty():
		return false
	present(event)
	return true


func present(event: Dictionary) -> void:
	app.engine.brake = true
	app.engine.speed = 0
	app.calendar.factor = 1 # YODA0x2318 scene prelude.
	app.session.paused = true
	app._boudoir_session.leave()
	app._modal.hide()
	app.instruments.hide()
	_messages = event.get("messages", []).duplicate()
	page = 0
	_notice = false
	_show_page()


func _show_page() -> void:
	var event: Dictionary = state.pending
	var lines: Array[String] = []
	if event.has("epitaph") and event.scene == "death":
		lines = state.message(int(event.epitaph), true)
	elif page < _messages.size():
		lines = state.message(int(_messages[page]))
	screen.present(event.get("scene", ""), lines,
		event.get("code_input", false) and page == _messages.size() - 1,
		event.get("scene") == "whale_question")


func _continue() -> void:
	if _notice:
		screen.hide()
		_notice = false
		if _return_room == "city":
			app._city_panel.show()
		else:
			app._open_panel(_return_room)
		return
	page += 1
	if page < _messages.size():
		_show_page()
		return
	var event: Dictionary = state.dismiss()
	if event.get("scene") == "sun":
		screen.present("sun-restored", [])
		_messages = []
		state.pending = {"scene": "sun_end", "messages": []}
		return
	if event.get("scene") in ["death", "sun_end"]:
		screen.hide()
		app._open_panel("options")
		return
	screen.hide()
	if app.journey.at_station():
		app.depart_from_city()
	elif event.get("reverse", false):
		app.journey.reverse_direction()
		app.world_view.update_train()
	app.session.paused = false
	app._open_panel("room")


func _submit_code(value: String) -> void:
	var result: Dictionary = state.submit_code(value, app.stoup)
	if result.accepted:
		_messages = [91]
		page = 0
		_show_page()
	else:
		screen.lines = state.message(63)
		screen.input_code = ""
		screen.queue_redraw()


func _answer(proceed: bool) -> void:
	var event: Dictionary = state.choose_whale(proceed)
	if proceed:
		present(event)
	else:
		screen.hide()
		app.session.paused = false
		app._open_panel("room")


func die(reason: int) -> void:
	present(state.die(reason))


func reset() -> void:
	state.reset()
	selection = ""
	crew_menu = ""
	if screen != null:
		screen.hide()


func blocks_simulation() -> bool:
	return screen != null and screen.visible and not _notice


func handle_key(event: InputEventKey) -> bool:
	if screen != null and screen.visible:
		screen.handle_key(event)
		return true
	return false


func advance_spies() -> void:
	state.sync_recruits(app.trade)
	state.advance_spies(app.network, app.trade, app.stoup)


func show_town(id: int) -> void:
	_return_room = "city"
	_notice = true
	screen.present("", state.message(id, true))


func read_stoup() -> void:
	_return_room = "boudoir" if app._boudoir_session.view.visible else "quarters"
	var item: Dictionary = app.stoup.pop()
	if item.is_empty():
		return
	var id: int = item.message_id
	# ROOM0x267 discards mine slot IDs<51; story125..127 handled TEXTEK0x46f8.
	if id < 51:
		return
	_notice = true
	screen.present("", state.message(id))


func open_spy_menu() -> void:
	_return_room = "quarters"
	state.sync_recruits(app.trade)
	var states: Array = []
	for record in state.spies:
		states.append(record[0])
	var actions = preload("res://scripts/quarters_actions.gd")
	if not actions.can_send_spy(states) and not actions.can_dynamite(states):
		_notice = true
		screen.present("", state.message(9))
		return
	crew_menu = "spies"
	screen.open_menu(["SEND SPY", "DYNAMITE", "EXIT"])


func open_car_menu() -> void:
	_return_room = "quarters"
	if preload("res://scripts/quarters_actions.gd").cars_count(app.wagons) == 0:
		_notice = true
		screen.present("", state.message(8))
		return
	crew_menu = "cars"
	screen.open_menu(["LINE INSPECTION CAR", "MISSILE CAR", "EXIT"])


func _menu_choice(index: int) -> void:
	if index == 2:
		screen.hide()
		selection = ""
		crew_menu = ""
		return
	if crew_menu == "cars":
		_car_missile = index == 1
		if _car_missile and preload("res://scripts/quarters_actions.gd").missiles_count(app.wagons) == 0:
			_notice = true
			screen.present("", state.message(15))
			return
		crew_menu = "car_direction"
		var vertical: bool = app.journey.heading in [2, 8]
		screen.open_menu(["SOUTH" if vertical else "WEST", "NORTH" if vertical else "EAST", "EXIT"])
	elif crew_menu == "car_direction":
		var vertical: bool = app.journey.heading in [2, 8]
		var heading: int = ([2, 8] if vertical else [4, 6])[index]
		app.engine.speed = 0
		app.engine.brake = true
		var result: Dictionary = preload("res://scripts/inspection_car.gd").launch(app.journey.position, app.journey.heading,
			app.journey.phase, heading, _car_missile, app.wagons, app.network, app.encounters.enemies)
		app._on_cargo_changed()
		_notice = true
		crew_menu = ""
		screen.present("", state.message(result.message))
	elif crew_menu == "spies":
		selection = "send" if index == 0 else "dynamite"
		screen.hide()
		app._open_panel("overview")


func select_map_cell(cell: Vector2i) -> bool:
	if selection.is_empty():
		return false
	if selection == "send":
		state.send_spy(cell, app.journey.position, app.wagons, app.trade)
		app._on_cargo_changed()
	else:
		for index in State.SPY_COUNT:
			var record: Array = state.spies[index]
			if Vector2i(record[1] + 40, record[2]) == cell:
				state.sabotage(index, app.network, app.stoup)
				break
	selection = ""
	app._open_panel("quarters")
	return true


func snapshot() -> Dictionary:
	var presentation := {"visible": false, "scene": "", "lines": [], "input_code": "",
		"entering_code": false, "question": false, "menu": []}
	if screen != null:
		for key in presentation:
			presentation[key] = screen.get(key)
	return {"version": 1, "state": state.snapshot(), "page": page,
		"selection": selection, "crew_menu": crew_menu, "notice": _notice,
		"return_room": _return_room, "car_missile": _car_missile, "presentation": presentation}


static func validate_snapshot(value: Variant) -> bool:
	return preload("res://scripts/campaign_snapshot.gd").validate(value)


func restore(value: Variant) -> bool:
	if not validate_snapshot(value):
		return false
	var candidate = State.new()
	candidate.data = state.data
	candidate.restore(value.state)
	state = candidate
	page = int(value.page)
	selection = value.selection
	crew_menu = value.crew_menu
	_notice = value.notice
	_return_room = value.return_room
	_car_missile = value.car_missile
	_messages = state.pending.get("messages", []).duplicate()
	if screen != null:
		for key in value.presentation:
			if key in ["lines", "menu"]:
				var strings: Array[String] = []
				for line in value.presentation[key]:
					strings.append(line)
				screen.set(key, strings)
			else:
				screen.set(key, value.presentation[key])
		screen.queue_redraw()
	return true
