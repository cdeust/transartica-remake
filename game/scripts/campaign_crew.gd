extends RefCounted

# MIT. Source: ROOM/CARTE/TIME crew actions; campaign session owns transitions.
const State = preload("res://scripts/campaign_state.gd")
var state = State.new()
var app
var screen
var selection := ""
var crew_menu := ""
var _notice := false
var _return_room := "quarters"
var _car_missile := false


func read_stoup() -> void:
	_return_room = "boudoir" if app._boudoir_session.view.visible else "quarters"
	var item: Dictionary = app.stoup.pop()
	if item.is_empty():
		return
	var id: int = item.message_id
	_notice = true
	if id < 51:
		screen.present("report", app.world.mines.report(id - 1, state.data.get("mine_bulletin", {})))
	elif id <= 120 and id >= 101:
		screen.present("report", preload("res://scripts/spy_report.gd").format(id - 101, state.spies, app.encounters.enemies, state.data, call("_mover_report_context")))
	else:
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
			app.journey.phase, heading, _car_missile, app.wagons, app.network, app.encounters.enemies, {"hazards": state.hazards, "rng": app._trade_rng, "calendar": app.calendar})
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
				selection = ""
				call("present", state._event("sabotage_confirm", [], {"spy": index}))
				return true
	selection = ""
	app._open_panel("quarters")
	return true
