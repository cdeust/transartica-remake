extends "res://scripts/campaign_crew.gd"

# MIT. UI owner; source-supported state changes are isolated in CampaignState.
const Screen = preload("res://scripts/campaign_screen.gd")
var page := 0
var _messages: Array = []


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
	if event.get("reverse", false):
		app.journey.reverse_direction()
		app.world_view.update_train()
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
		event.get("scene") in ["whale_question", "spy_pickup", "sabotage_confirm"])


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
	page = 0
	if event.get("scene") == "sun":
		screen.present("sun-restored", [])
		_messages = []
		state.pending = {"scene": "sun_end", "messages": []}
		return
	if event.get("scene") == "death":
		screen.present("earth", [])
		state.pending = {"scene": "earth", "messages": []}
		_messages = []
		return
	if event.get("scene") in ["earth", "sun_end"]:
		screen.hide()
		app._open_panel("options")
		return
	screen.hide()
	if app.journey.at_station():
		app.depart_from_city()
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
	if state.pending.get("scene") == "sabotage_confirm":
		if proceed:
			state.sabotage(int(state.pending.spy), app.network, app.stoup)
		state.dismiss()
		page = 0
		screen.hide()
		app.session.paused = false
		app._open_panel("quarters")
		return
	if state.pending.get("scene") == "spy_pickup":
		state.retrieve_spy(state.pending.spy, proceed, app.trade)
		state.dismiss()
		page = 0
		screen.hide()
		app.session.paused = false
		app._open_panel("room")
		return
	var event: Dictionary = state.choose_whale(proceed)
	if proceed:
		present(event)
	else:
		screen.hide()
		app.session.paused = false
		app._open_panel("room")


func die(reason: int) -> void:
	present(state.die(reason))


# TIME0x11a sends YODA26(reason102); TIME0x180 sends reason101.
func present_engine_event() -> bool:
	if not app.engine.event_pending or not state.pending.is_empty() or not state.ending.is_empty():
		return false
	var reasons := {"Boiler overload": 102, "No coal remaining": 101}
	if not reasons.has(app.engine.event_message):
		return false
	die(reasons[app.engine.event_message])
	return true


func reset() -> void:
	state.reset()
	page = 0
	_messages = []
	_notice = false
	_return_room = "quarters"
	_car_missile = false
	selection = ""
	crew_menu = ""
	if screen != null:
		screen.hide()


func blocks_simulation() -> bool:
	return screen != null and screen.visible


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


func snapshot() -> Dictionary:
	var presentation := {"visible": false, "scene": "", "lines": [], "input_code": "",
		"entering_code": false, "question": false, "menu": []}
	if screen != null and screen.visible:
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
