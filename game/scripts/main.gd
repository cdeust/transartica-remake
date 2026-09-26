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
const TrainWagonsScript = preload("res://scripts/train_wagons.gd")
# source: tasks/evidence/engine-room-integration.md; provisional real-time calibration.
const SECONDS_PER_CYCLE := 1.0

var journey = preload("res://scripts/train_journey.gd").new()
var network = RailNetworkScript.new()
var wagons = TrainWagonsScript.new()
var trade = CityTradeScript.new()
var _trade_rng := RandomNumberGenerator.new()
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
var _journal: RichTextLabel
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
	var blocked: bool = (_modal.visible and _journal.visible) or room_controls.show_help or _city_panel.visible
	if not blocked:
		session.advance(delta)
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
	var header := HBoxContainer.new()
	body.add_child(header)
	_modal_title = Label.new()
	_modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_modal_title)
	var overview := Button.new()
	overview.text = "Known area"
	overview.pressed.connect(func(): world_view.fit_discovered())
	header.add_child(overview)
	var close := Button.new()
	close.text = "Return to engine room · Esc"
	close.pressed.connect(func(): _modal.hide())
	header.add_child(close)
	_build_map(body)
	_build_journal(body)
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


func _build_journal(body: VBoxContainer) -> void:
	_journal = RichTextLabel.new()
	_journal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_journal.bbcode_enabled = true
	_journal.add_theme_font_size_override("normal_font_size", 22)
	_journal.text = "[b]IN SEARCH OF THE SUN[/b]\n\nThe world lies beneath ice and a permanent cloud cover. The Viking Union controls the great trains. Your stolen Transarctica carries a small group seeking evidence that the Sun can return.\n\n[b]Keep the locomotive alive[/b]\nLignite feeds the boiler and pays for supplies. Anthracite provides more heat. Watch the reserve, manage the stokers and use the brake without forgetting the fire.\n\nThis engine-room preview preserves the decoded locomotive calculations. The first eastbound trial route is connected. Junction choices, campaign, trade and crew management are not connected yet. The real-time pace is provisional."
	body.add_child(_journal)
	_journal.hide()


# Arrival scene for TIME message 76 (tasks/evidence/station-arrival.md): the
# glieu menu and its transactions (tasks/evidence/city-scripts.md), in city_screen.gd.
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
	if panel in ["instruments", "room"]:
		instruments.visible = panel == "instruments"
		room_controls.show_instruments = instruments.visible
		_modal.hide()
		return
	instruments.hide()
	_modal_title.text = "   TRANSARCTICA · WORLD" if panel == "map" else "   CAPTAIN'S JOURNAL"
	_map_panel.visible = panel == "map"
	_journal.visible = panel == "journal"
	_modal.show()
	if panel == "map" and not _map_opened:
		await get_tree().process_frame
		world_view.zoom = 1.0
		world_view.following_train = false
		world_view.update_train()
		world_view.center_on_train()
		_map_opened = true
	_update_status()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE:
		_modal.hide()
		room_controls.show_help = false
		room_controls.show_instruments = false
		instruments.hide()
		get_viewport().set_input_as_handled()
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
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
		KEY_F6: _restore_view()
		KEY_R: _restart_engine()
		_: return
	get_viewport().set_input_as_handled()


func _restart_engine() -> void:
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
	var path := _save_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	# No "consist" key: the drawn composition is derived from "wagons" at
	# restore time (train_consist.gd::derive_from_wagons), never saved as an
	# independent list that could drift from the wagons table.
	var state := {"version": 7, "wagons": wagons.snapshot(), "trade": trade.snapshot(), "travel_camera": {"x": world_view.camera_world.x, "y": world_view.camera_world.y, "follow": world_view.following_train}, "journey": journey.snapshot(), "network": network.snapshot(), "session": session.snapshot(), "discovery": world_view.discovery.snapshot(), "zoom": world_view.zoom, "offset_x": world_view.offset.x, "offset_y": world_view.offset.y, "selected_city": world_view.selected_city, "elapsed_seconds": clock.elapsed_seconds}
	file.store_string(JSON.stringify(state))
	return true


func _save_view() -> void:
	room_controls.announce("Engine session saved" if save_view() else "Could not save engine session")


func _restore_view() -> void:
	var path := _save_path()
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		room_controls.announce("Save file is invalid; current session kept")
		return
	var restored_discovery = preload("res://scripts/map_discovery.gd").new()
	if parsed.has("discovery") and not restored_discovery.restore(parsed.discovery):
		room_controls.announce("Discovery save is invalid; current session kept")
		return
	var restored_network = RailNetworkScript.new()
	restored_network.load_bytes(world_data.map_bytes)
	if parsed.has("network") and not restored_network.restore(parsed.network):
		room_controls.announce("Switch save is invalid; current session kept")
		return
	var restored_journey = preload("res://scripts/train_journey.gd").new()
	restored_journey.network = restored_network
	if parsed.has("journey") and not restored_journey.restore(parsed.journey):
		room_controls.announce("Journey save is invalid; current session kept")
		return
	# "consist" (v7 saves before this composition-derivation change) is
	# accepted and ignored: composition is derived from "wagons" below, never
	# read back as its own list, so an old save cannot diverge from its wagons.
	var restored_wagons = TrainWagonsScript.new()
	if parsed.has("wagons") and not restored_wagons.restore(parsed.wagons):
		room_controls.announce("Cargo save is invalid; current session kept")
		return
	var restored_consist = preload("res://scripts/train_consist.gd").new()
	restored_consist.derive_from_wagons(restored_wagons)
	# Root-cause note (found while recalibrating LENGTHS for the overhead art,
	# tasks/todo.md "Decision : train en vue de dessus"): this used to check
	# against the WHOLE consist's length_world(). The overhead LENGTHS are
	# less differentiated than the old oblique ones (all near 1.0 cell
	# instead of 0.75-1.0), so their sum grew past the ~5.0-cell decoded
	# track history that genuinely exists behind START_POSITION before the
	# train has ever moved (train_path.gd::seed stops where the decoded rails
	# stop or turn ambiguous -- not a guessed bound). Rejecting the whole
	# restore on that account was stricter than what the renderer actually
	# needs: poses() already renders a partial consist gracefully when later
	# wagons lack history ("insufficient history omits poses without
	# off-track extrapolation", game/tests/test_travel_world.gd), and a
	# newly-departed train is explicitly allowed to be missing wagon history
	# (history_starts_in_station(), train_journey.gd). The minimum a restored
	# journey must place is the locomotive itself.
	if not restored_journey.sample_behind(restored_consist.LENGTHS.locomotive).ok and not restored_journey.history_starts_in_station():
		room_controls.announce("This save cannot recover wagon positions. Current journey kept; saved file unchanged.")
		return
	var restored_trade = CityTradeScript.new()
	if parsed.has("trade") and not restored_trade.restore(parsed.trade):
		room_controls.announce("City stock save is invalid; current session kept")
		return
	if parsed.has("session") and not session.restore(parsed.session):
		room_controls.announce("Save state is invalid; current session kept")
		return
	if parsed.has("network"):
		network.restore(parsed.network)
	else:
		network.reset()
	journey.restore(restored_journey.snapshot())
	# Saves before version 7 carry no cargo: they resume with the TABLE train and fresh stocks.
	wagons.restore(restored_wagons.snapshot())
	if parsed.has("trade"):
		trade.restore(restored_trade.snapshot())
	else:
		trade.reset(_trade_rng)
	engine.train_mass = wagons.mass()
	world_view.consist.derive_from_wagons(wagons)
	world_view._visual_initialized = false
	_restore_chart(parsed)
	world_view.visit_cell(journey.position)
	room_controls.announce("Journey and engine restored" if parsed.has("journey") else "Previous engine restored · first journey starts at departure")
	_city_panel.hide()
	if journey.station_result() >= 0:
		_open_city(journey.station_result())


func _restore_chart(parsed: Dictionary) -> void:
	if parsed.has("discovery"):
		world_view.discovery.restore(parsed.discovery)
	_filter_cities(search_box.text)
	world_view.zoom = clampf(float(parsed.get("zoom", world_view.zoom)), WorldViewScript.TRAVEL_MIN_ZOOM, WorldViewScript.TRAVEL_MAX_ZOOM)
	world_view.offset = Vector2(float(parsed.get("offset_x", world_view.offset.x)), float(parsed.get("offset_y", world_view.offset.y)))
	var city_index := int(parsed.get("selected_city", -1))
	world_view.selected_city = city_index if city_index >= 0 and city_index < world_data.cities.size() and _city_discovered(city_index) else -1
	clock.set_elapsed(float(parsed.get("elapsed_seconds", 0.0)))
	_map_opened = parsed.has("travel_camera")
	if _map_opened and parsed.travel_camera is Dictionary:
		world_view.camera_world = Vector2(float(parsed.travel_camera.get("x", 12.5)), float(parsed.travel_camera.get("y", 62.5)))
		world_view.following_train = bool(parsed.travel_camera.get("follow", false))
	world_view._refresh_discovery_mask()
	if not parsed.has("discovery"):
		world_view.fit_discovered()
	world_view.queue_redraw()
	_update_status()
	city_list.deselect_all()
	_select_visible_city()


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
	if OS.has_feature("template"):
		var executable_dir := OS.get_executable_path().get_base_dir()
		if OS.has_feature("macos"):
			executable_dir = executable_dir.get_base_dir().get_base_dir().get_base_dir()
		return executable_dir.path_join("save/view.json")
	return ProjectSettings.globalize_path("res://save/view.json")


func _advance_journey() -> void:
	if engine.event_pending:
		return
	journey.advance(engine.speed)
	world_view.visit_cell(journey.position)
	world_view.update_train()
	_filter_cities(search_box.text)
	_update_status()
	if _map_panel.visible:
		_modal_title.text = "   TRANSARCTICA · (%d, %d) %s · %d km/h" % [journey.position.x, journey.position.y, journey.heading_name(), engine.speed]
	if journey.blocked:
		var station := journey.station_result()
		if station >= 0:
			_open_city(station)
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
