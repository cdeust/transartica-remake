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
var encounters = preload("res://scripts/world_encounters.gd").new()
var campaign = preload("res://scripts/campaign_session.gd").new()
var game_audio = preload("res://scripts/game_audio.gd").new()
@export var play_startup_intro := false
var _boot = preload("res://scripts/game_boot.gd").new()
var world = preload("res://scripts/world_actions.gd").new()
var roamers = preload("res://scripts/world_roamers.gd").new()
var _world_session = preload("res://scripts/world_session.gd").new()
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
	world_view.visual_clock = clock
	game_audio.attach(self)
	world.attach(journey, wagons, engine, trade, _trade_rng)
	_world_session.attach(self)
	campaign.attach(self)
	roamers.initialize(_trade_rng, campaign.state.fauna)
	network.campaign_entry_enabled = true
	_city_panel.town_message_requested.connect(campaign.show_town)
	encounters.attach(self)
	session.cycle_completed.connect(_advance_journey)
	world_view.journey = journey
	# Rendered composition is derived from the wagon-rules table, never an
	# independent list (tasks/todo.md, "Decision : train en vue de dessus").
	world_view.consist.derive_from_wagons(wagons)
	_restore_after_layout()


func _process(delta: float) -> void:
	if session == null or room_controls == null:
		return
	var blocked: bool = encounters.report.visible or encounters.manual_scene.visible or campaign.blocks_simulation() or _world_session.blocks_simulation() or _boudoir_session.blocks_simulation() or room_controls.show_help or _city_panel.visible \
			or (works_dialog != null and works_dialog.visible)
	_world_session.advance_text(delta)
	if not blocked:
		session.advance(delta * calendar.factor)
	campaign.present_engine_event()
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
	preload("res://scripts/main_interface.gd")._build_interface(self)


func _build_modal() -> void:
	preload("res://scripts/main_interface.gd")._build_modal(self)


func _reverse_at_event() -> void:
	engine.brake = true
	engine.speed = 0
	works_dialog.inform(52)
	journey.depart_from_station()
	world_view.update_train()


func _advance_calendar() -> void:
	encounters.advance_calendar()
	world.tick_mines(calendar.day, stoup)
	campaign.advance_spies()

func _build_works_dialog() -> void:
	preload("res://scripts/main_interface.gd")._build_works_dialog(self)


func _on_works_finished(repaired: bool) -> void:
	engine.train_mass = wagons.mass()
	if works_dialog.kind.is_empty():
		status_label.text = "Turned back · heading %s." % journey.heading_name()
		return
	var ahead: Vector2i = works_dialog.last_cell
	status_label.text = ("Track repaired at (%d, %d)." if repaired else "Still blocked at (%d, %d).") % [ahead.x, ahead.y]
	world_view.queue_redraw()


func _build_city_screen() -> void:
	preload("res://scripts/main_interface.gd")._build_city_screen(self)


func _open_city(index: int) -> void:
	if campaign.before_city(index):
		return
	preload("res://scripts/game_audio_routes.gd").city(self, index)
	world.visit_city(index)
	trade.visit(index, _trade_rng)
	_show_city(index)


func _show_city(index: int) -> void:
	preload("res://scripts/main_interface.gd").show_city(self, index)


# TIME 0x2a77/0x2b4a weigh the cargo: trading changes the train mass. Buying
# or losing a wagon also changes the drawn composition; both are derived from
# the same wagons table, never set independently.
func _on_cargo_changed() -> void:
	engine.train_mass = wagons.mass()
	world_view.consist.derive_from_wagons(wagons)
	world_view.update_train()
	_update_status()


func depart_from_city() -> void:
	if not _world_session.depart_nomads() and not journey.depart_from_station():
		return
	preload("res://scripts/game_audio_routes.gd").departure(self)
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
		if panel == "room" and encounters.pending >= 0 and encounters.manual != null:
			encounters.manual_scene.open_battle(encounters.manual)
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
	preload("res://scripts/gameplay_input.gd")._unhandled_key_input(self, event)


func _restart_engine() -> void:
	preload("res://scripts/game_reset.gd").restart(self)


func _restore_after_layout() -> void:
	_boot.restore_after_layout(self)


func focus_city(index: int) -> void:
	preload("res://scripts/city_index.gd").focus_city(self, index)


func save_view() -> bool:
	return preload("res://scripts/session_saves.gd").save(self, _save_path()).ok


func _save_view() -> void:
	room_controls.announce("Engine session saved" if save_view() else "Could not save engine session")


func _restore_view() -> void:
	var result: Dictionary = preload("res://scripts/session_saves.gd").restore(self, _save_path())
	if not result.notice.is_empty():
		room_controls.announce(result.notice)


func _filter_cities(query: String) -> void:
	preload("res://scripts/city_index.gd")._filter_cities(self, query)


func _on_chart_city_picked(_index: int) -> void:
	preload("res://scripts/city_index.gd")._on_chart_city_picked(self, _index)


func _on_city_selected(list_index: int) -> void:
	preload("res://scripts/city_index.gd")._on_city_selected(self, list_index)


func _select_visible_city() -> void:
	preload("res://scripts/city_index.gd")._select_visible_city(self)


func _on_switch_toggled(cell: Vector2i) -> void:
	var diverging: bool = network.switch_diverges(cell)
	room_controls.announce("Switch (%d, %d) set to %s" % [cell.x, cell.y, "branch" if diverging else "main line"])


func _update_status() -> void:
	preload("res://scripts/city_index.gd")._update_status(self)


func _city_discovered(index: int) -> bool:
	return preload("res://scripts/city_index.gd")._city_discovered(self, index)


func _save_path() -> String:
	if not save_path_override.is_empty():
		return save_path_override
	return preload("res://scripts/session_saves.gd").default_path()


func _advance_journey() -> void:
	preload("res://scripts/journey_session.gd").advance(self)
