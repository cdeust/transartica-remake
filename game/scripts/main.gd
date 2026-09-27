extends Control

const SurveyClockScript = preload("res://scripts/survey_clock.gd")
const WorldDataScript = preload("res://scripts/world_data.gd")
const WorldViewScript = preload("res://scripts/travel_world.gd")
const EngineStateScript = preload("res://scripts/engine_state.gd")
const EngineSessionScript = preload("res://scripts/engine_session.gd")
const RoomArtScript = preload("res://scripts/engine_room_art.gd")
const RoomControlsScript = preload("res://scripts/engine_room_controls.gd")
const AtlasThemeScript = preload("res://scripts/atlas_theme.gd")
const RailNetworkScript = preload("res://scripts/rail_network.gd")
const CityScreenScript = preload("res://scripts/city_screen.gd")
const CityTradeScript = preload("res://scripts/city_trade.gd")
const WorksDialogScript = preload("res://scripts/works_dialog.gd")
const GameCalendarScript = preload("res://scripts/game_calendar.gd")
const TrainWagonsScript = preload("res://scripts/train_wagons.gd")
# source: tasks/evidence/engine-room-integration.md; provisional real-time calibration.
const SECONDS_PER_CYCLE := 1.0

var journey = preload("res://scripts/train_journey.gd").new()
var network = RailNetworkScript.new()
var wagons = TrainWagonsScript.new()
var trade = CityTradeScript.new()
var _trade_rng := RandomNumberGenerator.new()
var works_dialog
var calendar = GameCalendarScript.new()
var travel_controls
var clock
var engine
var session
var room_art
var room_controls
var instruments
var world_data
var world_view
var city_list: ItemList
var search_box: LineEdit
var status_label: Label
var city_indices: Array[int] = []
var save_path_override := ""
var _modal: PanelContainer
var _map_panel: VBoxContainer
var stoup = preload("res://scripts/stoup_messages.gd").new()
var boudoir
var _boudoir_session = preload("res://scripts/boudoir_session.gd").new()
var _modal_title: Label
var _map_opened := false
var _city_panel


func _ready() -> void:
	clock = SurveyClockScript.new()
	engine = EngineStateScript.new()
	session = EngineSessionScript.new(engine, SECONDS_PER_CYCLE)
	world_data = WorldDataScript.new()
	var root_path := ProjectSettings.globalize_path("res://").trim_suffix("/")
	if not world_data.load_from_project(root_path):
		push_error("Local reference map or 46-city dataset is unavailable.")
		set_process(false)
		return
	if not network.load_bytes(world_data.map_bytes):
		push_error("Local reference map has an unexpected size.")
		set_process(false)
		return
	network.set_city_anchors(world_data.city_anchors())
	if not trade.load_from_project(root_path):
		push_error("Local commerce table is unavailable (python3 tools/build_commerce_data.py).")
		set_process(false)
		return
	_trade_rng.randomize()
	trade.reset(_trade_rng)
	engine.train_mass = wagons.mass()
	journey.network = network
	_build_interface()
	session.cycle_completed.connect(_advance_journey)
	world_view.journey = journey
	# Rendered composition is derived from the wagon-rules table, never an
	# independent list (tasks/todo.md, "Decision : train en vue de dessus").
	world_view.consist.derive_from_wagons(wagons)
	_restore_after_layout()


func _process(delta: float) -> void:
	if session == null or room_controls == null:
		return
	var blocked: bool = _boudoir_session.blocks_simulation() or room_controls.show_help or _city_panel.visible \
			or (works_dialog != null and works_dialog.visible)
	if not blocked:
		session.advance(delta * calendar.factor)
	_boudoir_session.present_pending_event()
	clock.paused = session.paused or blocked or engine.event_pending
	clock.advance(delta)
	room_art.paused = clock.paused
	room_art.advance_visual(delta)
	room_controls.refresh(delta)
	if travel_controls != null and _modal.visible:
		travel_controls.refresh()
	if instruments != null and instruments.visible:
		instruments.refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and session != null:
		session.paused = true


func _build_interface() -> void:
	theme = AtlasThemeScript.create_theme()
	room_art = RoomArtScript.new()
	room_art.engine = engine
	room_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(room_art)
	room_controls = RoomControlsScript.new()
	room_controls.art = room_art
	room_controls.session = session
	room_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room_controls.requested.connect(_open_panel)
	add_child(room_controls)
	instruments = preload("res://scripts/engine_instruments.gd").new()
	instruments.bind_session(session)
	instruments.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	instruments.requested.connect(_open_panel)
	add_child(instruments)
	instruments.hide()
	_build_modal()
	_build_city_screen()
	_build_works_dialog()
	_boudoir_session.attach(self)
	boudoir = _boudoir_session.view


func _build_modal() -> void:
	_modal = PanelContainer.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen_style := StyleBoxFlat.new()
	screen_style.bg_color = Color("#0d1b23")
	screen_style.content_margin_left = 0
	screen_style.content_margin_right = 0
	screen_style.content_margin_top = 0
	screen_style.content_margin_bottom = 0
	_modal.add_theme_stylebox_override("panel", screen_style)
	add_child(_modal)
	var body := VBoxContainer.new()
	_modal.add_child(body)
	_modal_title = Label.new()
	body.add_child(_modal_title)
	_modal_title.hide()
	_build_map(body)
	_modal.hide()


func _build_map(body: VBoxContainer) -> void:
	_map_panel = VBoxContainer.new()
	_map_panel.add_theme_constant_override("separation", 0)
	_map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_map_panel)
	world_view = WorldViewScript.new()
	world_view.world_data = world_data
	world_view.session = session
	world_view.network = network
	world_view.switch_toggled.connect(_on_switch_toggled)
	world_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	world_view.city_picked.connect(_on_chart_city_picked)
	_map_panel.add_child(world_view)
	travel_controls = preload("res://scripts/travel_hud.gd").new()
	travel_controls.bind_session(session)
	travel_controls.journey = journey
	travel_controls.requested.connect(_open_panel)
	travel_controls.follow_requested.connect(world_view.follow_train)
	_map_panel.add_child(travel_controls)
	travel_controls.hide()
	_build_hidden_city_index()


func _build_hidden_city_index() -> void:
	# Keep the city selection model available without a dashboard beside the world.
	var index_container := VBoxContainer.new()
	_map_panel.add_child(index_container)
	search_box = LineEdit.new()
	search_box.text_changed.connect(_filter_cities)
	index_container.add_child(search_box)
	city_list = ItemList.new()
	city_list.item_selected.connect(_on_city_selected)
	index_container.add_child(city_list)
	status_label = Label.new()
	index_container.add_child(status_label)
	index_container.hide()
	_filter_cities("")


# Arrival scene for TIME message 76 (tasks/evidence/station-arrival.md): the
# glieu menu and its transactions (tasks/evidence/city-scripts.md), in city_screen.gd.
# YODA 0x104 (-120): brake, TEXTEK 52, then the 0x18e3 reversal with speed 0.
func _reverse_at_event() -> void:
	engine.brake = true
	engine.speed = 0
	works_dialog.inform(52)
	journey.depart_from_station()
	world_view.update_train()


func _advance_calendar() -> void:
	for event in calendar.advance_cycle():
		if event in ["bridge_open", "bridge_closed"]:
			network.set_timed_bridge(calendar.bridge_code())
			world_view.queue_redraw()


func _build_works_dialog() -> void:
	works_dialog = WorksDialogScript.new()
	works_dialog.journey = journey
	works_dialog.wagons = wagons
	works_dialog.rng = _trade_rng
	if not works_dialog.load_texts(ProjectSettings.globalize_path("res://")):
		push_warning("TEXTEK texts unavailable (python3 tools/claude/export_textek.py); message ids shown instead.")
	works_dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	works_dialog.finished.connect(_on_works_finished)
	add_child(works_dialog)


# YODA 0x2390: the train stays braked in front of the cell; a repair lets TIME retry the entry.
func _on_works_finished(repaired: bool) -> void:
	engine.train_mass = wagons.mass()
	if works_dialog.kind.is_empty():
		status_label.text = "Turned back · heading %s." % journey.heading_name()
		return
	var ahead: Vector2i = journey.next_cell()
	status_label.text = ("Track repaired at (%d, %d)." if repaired else "Still blocked at (%d, %d).") % [ahead.x, ahead.y]
	world_view.queue_redraw()


func _build_city_screen() -> void:
	_city_panel = CityScreenScript.new()
	_city_panel.trade = trade
	_city_panel.wagons = wagons
	_city_panel.engine = engine
	_city_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_city_panel.depart_requested.connect(depart_from_city)
	_city_panel.cargo_changed.connect(_on_cargo_changed)
	add_child(_city_panel)
	_city_panel.hide()


func _open_city(index: int) -> void:
	var city: Dictionary = world_data.cities[index]
	trade.visit(index, _trade_rng)
	# Adaptation: the travel clock pauses while the city is open; whether time
	# runs during the original city scene is not established.
	session.paused = true
	_city_panel.open(index, String(city.name), int(city.kind), String(city.type))
	_city_panel.position = (size - _city_panel.size) * 0.5
	world_view.selected_city = index
	room_controls.announce("Arrived at %s" % String(city.name))


# TIME 0x2a77/0x2b4a weigh the cargo: trading changes the train mass. Buying
# or losing a wagon also changes the drawn composition; both are derived from
# the same wagons table, never set independently.
func _on_cargo_changed() -> void:
	engine.train_mass = wagons.mass()
	world_view.consist.derive_from_wagons(wagons)
	world_view.update_train()
	_update_status()


func depart_from_city() -> void:
	if not journey.depart_from_station():
		return
	engine.speed = 0 # yoda 0x18e3 writes 0 to main+0x2fb4, the effective speed.
	_city_panel.hide()
	session.paused = false
	world_view.update_train()
	_update_status()
	_modal_title.text = "   TRANSARCTICA · (%d, %d) %s · %d km/h" % [journey.position.x, journey.position.y, journey.heading_name(), engine.speed]
	room_controls.announce("Departing · heading %s" % journey.heading_name())


func _open_panel(panel: String) -> void:
	if _boudoir_session.open_panel(panel):
		_modal.hide()
		instruments.hide()
		room_controls.show_instruments = false
		room_controls.show_help = false
		_boudoir_session.refresh()
		return
	_boudoir_session.leave()
	if panel in ["instruments", "room"]:
		_boudoir_session.last_room = "room"
		instruments.visible = panel == "instruments"
		room_controls.show_instruments = instruments.visible
		_modal.hide()
		_boudoir_session.refresh()
		return
	instruments.hide()
	room_controls.show_instruments = false
	room_controls.show_help = false
	_map_panel.show()
	_modal.show()
	_boudoir_session.refresh()
	if panel == "map" and not _map_opened:
		await get_tree().process_frame
		world_view.following_train = false
		world_view.update_train()
		world_view.fit_complete_consist()
		_map_opened = true
	_update_status()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	# LineEdit handles Unicode in unhandled_key_input too (Godot 4.5 line_edit.cpp).
	if get_viewport().gui_get_focus_owner() is LineEdit and event.physical_keycode not in [KEY_ESCAPE, KEY_F1]:
		return
	if _boudoir_session.handle_key(event):
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_ESCAPE:
		_modal.hide()
		room_controls.show_help = false
		room_controls.show_instruments = false
		instruments.hide()
		get_viewport().set_input_as_handled()
		return
	if _city_panel.visible:
		# Layout keycode: the - and + keys differ between QWERTY and AZERTY.
		if _city_panel.handle_key(event.keycode):
			get_viewport().set_input_as_handled()
		return
	match event.physical_keycode:
		KEY_L: room_controls.activate("lignite")
		KEY_A: room_controls.activate("anthracite")
		KEY_B: room_controls.activate("brake")
		KEY_SPACE: room_controls.activate("pause")
		KEY_H: room_controls.activate("help")
		KEY_M: _open_panel("map")
		KEY_J: _open_panel("journal")
		KEY_LEFT: engine.set_regulator(engine.regulator - (1 if event.shift_pressed else 15))
		KEY_RIGHT: engine.set_regulator(engine.regulator + (1 if event.shift_pressed else 15))
		KEY_F5: _save_view()
		KEY_F6: _open_panel("options")
		KEY_R: _restart_engine()
		_: return
	get_viewport().set_input_as_handled()


func _restart_engine() -> void:
	_boudoir_session.reset()
	session.reset()
	journey.reset()
	network.reset()
	wagons.reset()
	trade.reset(_trade_rng)
	engine.train_mass = wagons.mass()
	world_view.consist.derive_from_wagons(wagons)
	_city_panel.hide()
	world_view.selected_city = -1
	_map_opened = false
	world_view.following_train = false
	world_view.discovery = preload("res://scripts/map_discovery.gd").new()
	_filter_cities("")
	world_view.fit_discovered()
	clock.set_elapsed(0)
	calendar = GameCalendarScript.new()
	_modal.hide()
	instruments.hide()
	room_controls.announce("New engine session · coal stocks restored")


func _restore_after_layout() -> void:
	await get_tree().process_frame
	world_view.fit_discovered()
	_restore_view()
	_update_status()


func focus_city(index: int) -> void:
	world_view.focus_city(index)
	_update_status()


func save_view() -> bool:
	return preload("res://scripts/session_saves.gd").save(self, _save_path()).ok


func _save_view() -> void:
	room_controls.announce("Engine session saved" if save_view() else "Could not save engine session")


func _restore_view() -> void:
	var result: Dictionary = preload("res://scripts/session_saves.gd").restore(self, _save_path())
	if not result.notice.is_empty():
		room_controls.announce(result.notice)


func _filter_cities(query: String) -> void:
	city_list.clear()
	city_indices.clear()
	for index in world_data.cities.size():
		if not _city_discovered(index):
			continue
		var city_name := String(world_data.cities[index].name)
		if query.is_empty() or city_name.to_lower().contains(query.to_lower()):
			city_indices.append(index)
			city_list.add_item(city_name)


func _on_chart_city_picked(_index: int) -> void:
	_update_status()
	city_list.deselect_all()
	_select_visible_city()


func _on_city_selected(list_index: int) -> void:
	if list_index < city_indices.size():
		focus_city(city_indices[list_index])


func _select_visible_city() -> void:
	if city_list == null or world_view.selected_city < 0:
		return
	for index in city_indices.size():
		if city_indices[index] == world_view.selected_city:
			city_list.select(index)
			return


func _on_switch_toggled(cell: Vector2i) -> void:
	var diverging: bool = network.switch_diverges(cell)
	room_controls.announce("Switch (%d, %d) set to %s" % [cell.x, cell.y, "branch" if diverging else "main line"])


func _update_status() -> void:
	if status_label == null:
		return
	var selected := "No city selected"
	if world_view.selected_city >= 0:
		selected = String(world_data.cities[world_view.selected_city].name)
	status_label.text = "Position (%d, %d) · %s\n%s\n%d discovered cities" % [journey.position.x, journey.position.y, journey.heading_name(), selected, city_indices.size()]


func _city_discovered(index: int) -> bool:
	var city: Dictionary = world_data.cities[index]
	return world_view.discovery.is_discovered(int(city.x), int(city.y))


func _save_path() -> String:
	if not save_path_override.is_empty():
		return save_path_override
	return preload("res://scripts/session_saves.gd").default_path()


func _advance_journey() -> void:
	if engine.event_pending:
		return
	# TIME re-checks the cell once the brake is released (obstacles-unknowns.md §1).
	if journey.at_obstacle() and not engine.brake and not works_dialog.visible:
		journey.resume_after_works()
	var was_blocked: bool = journey.blocked
	_advance_calendar()
	journey.advance(engine.speed)
	world_view.visit_cell(journey.position)
	world_view.update_train()
	_filter_cities(search_box.text)
	_update_status()
	if _map_panel.visible:
		_modal_title.text = "   TRANSARCTICA · %s · (%d, %d) %s · %d km/h" % [calendar.display_text(), journey.position.x, journey.position.y, journey.heading_name(), engine.speed]
	if journey.blocked:
		var station := journey.station_result()
		if station >= 0:
			_open_city(station)
			return
		if journey.at_reversal_event():
			if not was_blocked:
				_reverse_at_event()
			return
		if journey.at_obstacle():
			# YODA 0x2318: the question brakes the train; asked once per refused entry.
			if not was_blocked:
				engine.brake = true
				engine.speed = 0
				works_dialog.ask(network)
			return
		engine.brake = true
		engine.speed = 0
		session.paused = true
		var ahead: Vector2i = journey.next_cell()
		var reason: String = journey.stop_reason
		if journey.at_station():
			# TIME 0x2483..0x24c3: -1 sends message 34, -2..-5 send messages 22..25.
			reason = "station without city (message 34)" if station == -1 else "story station (message %d)" % (absi(station) + 20)
		room_controls.announce("Stopped before %s at (%d, %d) · not yet ported" % [reason, ahead.x, ahead.y])
		status_label.text = "Stopped before %s at (%d, %d).\nR starts a new run." % [reason, ahead.x, ahead.y]
