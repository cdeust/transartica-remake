extends RefCounted

# source: enemy-trains.md §6, combat.md §9 and manual.txt lines264–266.
const Enemies = preload("res://scripts/enemy_trains.gd")
const Tactical = preload("res://scripts/tactical_combat.gd")
const Scene = preload("res://scripts/tactical_scene.gd")
const Result = preload("res://scripts/tactical_result.gd")
const Report = preload("res://scripts/combat_report.gd")
var enemies = Enemies.new()
var rng := RandomNumberGenerator.new()
var difficulty := 0 # source: TABLE0x249 new-game difficulty.
var automatic := false # source: TABLE0x255 combat enabled by default.
var pending := -1
var app
var report
var manual
var manual_scene
var manual_paused := false # source: authored scene pause state, independent of tactics.


func attach(owner_app) -> void:
	app = owner_app
	app.world_view.encounters = self
	app.world_view.wagons = app.wagons
	rng.randomize()
	report = Report.new()
	report.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.add_child(report)
	report.continued.connect(_continue)
	report.options_requested.connect(func(): report.hide(); app._open_panel("options"))
	app._boudoir_session.reception.combat_requested.connect(toggle_automatic)
	app._boudoir_session.reception.level_requested.connect(cycle_difficulty)
	manual_scene = Scene.new()
	if preload("res://scripts/game_audio_routes.gd").available(app):
		manual_scene.audio = app.game_audio
	manual_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.add_child(manual_scene)
	# Main owns configured keys; standalone tactical scenes keep their own router.
	manual_scene.set_process_unhandled_key_input(false)
	manual_scene.completed.connect(_finish_manual)
	manual_scene.save_requested.connect(func(): app.save_view())
	manual_scene.options_requested.connect(func(): manual_scene.hide(); app._open_panel("options"))
	_sync_options()


func reset() -> void:
	enemies.reset()
	pending = -1
	manual = null
	manual_paused = false
	if manual_scene != null:
		manual_scene.hide()
	if report != null:
		report.hide()


func advance_calendar() -> void:
	var prior_hour: int = app.calendar.hour
	for event in app.calendar.advance_cycle():
		if event in ["bridge_open", "bridge_closed"]:
			app.network.set_timed_bridge(app.calendar.bridge_code())
			app.world_view.queue_redraw()
		elif event == "new_day":
			enemies.maybe_spawn_on_day(app.calendar.day, difficulty, rng)
	if app.calendar.hour != prior_hour:
		enemies.maybe_spawn_on_hour(app.calendar.hour, difficulty, rng)


func advance(old_cell: Vector2i) -> bool:
	if pending >= 0:
		return true
	if old_cell != app.journey.position:
		enemies.record_player_position(app.journey.position, app.network)
		enemies.sync_scripted_slot(app.journey.position)
	# TIME checks the player's entry against enemies before they can leave it.
	var encountered: int = enemies.encounter_at(app.journey.position)
	if encountered < 0:
		var before: Array = []
		for slot in Enemies.SLOT_COUNT:
			before.append(enemies.cell(slot))
		enemies.advance_cycle(app.network, rng, app.journey.heading)
		_observe_enemy_moves(before)
		encountered = enemies.encounter_at(app.journey.position)
	if encountered < 0:
		return false
	pending = encountered
	app.session.paused = true
	app._open_panel("room")
	if automatic:
		resolve_pending()
	else:
		resume_pending()
	return true


func resume_pending() -> void:
	if pending < 0:
		return
	if manual == null:
		manual = Tactical.new()
		manual.begin(app.wagons, enemies.slots[pending][Enemies.STRENGTH], rng)
		manual_paused = false
	manual_scene.paused = manual_paused
	manual_scene.open_battle(manual)


func _finish_manual() -> void:
	if pending < 0 or manual == null or manual.outcome == 0:
		return
	var result: Dictionary = Result.commit(manual, app.wagons, app.engine, app.trade.spy_slots)
	if result.is_empty():
		return
	rng.state = manual.rng.state
	if result.won:
		enemies.remove(pending)
	pending = -1
	manual = null
	app._on_cargo_changed()
	app.session.paused = true
	_present_result(result)


func resolve_pending() -> void:
	if pending < 0 or not automatic or manual != null:
		return
	var result: Dictionary = load("res://scripts/automatic_combat.gd").resolve(app.wagons, app.engine, enemies.slots[pending][Enemies.STRENGTH], rng)
	if result.won:
		enemies.remove(pending)
	pending = -1
	app._on_cargo_changed()
	app.session.paused = true
	_present_result(result)


func _campaign():
	for property in app.get_property_list():
		if property.name == "campaign":
			return app.get("campaign")
	return null


func _observe_enemy_moves(before: Array) -> void:
	var campaign = _campaign()
	if campaign == null:
		return
	for slot in Enemies.SLOT_COUNT:
		if enemies.is_active(slot) and enemies.cell(slot) != before[slot]:
			# TIME0x20bb rotates the posted spy record after enemy movement.
			campaign.state.observe_enemy(slot,enemies.cell(slot),app.calendar,app.stoup)


func _present_result(result: Dictionary) -> void:
	var campaign = _campaign()
	if not result.won and campaign != null:
		# Manual YODA0xabb and automatic TEXTEK0x5435 both send epitaph105.
		manual_scene.hide()
		report.hide()
		campaign.die(105)
	else:
		report.open_report(result)


func _continue() -> void:
	if report.result.get("manual", false):
		return
	if report.result.get("won", false):
		app.session.paused = false
	else:
		app._open_panel("options")


func toggle_automatic() -> void:
	automatic = not automatic
	_sync_options()
	if automatic and pending >= 0 and manual == null:
		app._open_panel("room")
		resolve_pending()


func cycle_difficulty() -> void:
	# source: original difficulty domain0..4 in enemy-trains.md; manual options.
	difficulty = (difficulty + 1) % 5
	_sync_options()


func _sync_options() -> void:
	app._boudoir_session.reception.automatic_combat = automatic
	app._boudoir_session.reception.difficulty = difficulty
	app._boudoir_session.reception.queue_redraw()


func snapshot() -> Dictionary:
	# Decimal strings avoid JSON float rounding of PCG's64-bit state.
	var paused: bool = manual_scene.paused if manual_scene != null else manual_paused
	return {"version": 1, "enemies": enemies.snapshot(), "difficulty": difficulty,
		"automatic": automatic, "pending": pending, "seed": str(rng.seed), "state": str(rng.state), "manual": manual.snapshot() if manual != null else null,
		"manual_paused": paused and manual != null}


func restore(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 1:
		return false
	for key in ["difficulty", "pending"]:
		if not data.get(key) is float and not data.get(key) is int:
			return false
		if not is_finite(data[key]) or data[key] != floor(data[key]):
			return false
	if data.difficulty < 0 or data.difficulty > 4 or data.pending < -1 or data.pending >= Enemies.SLOT_COUNT or not data.get("automatic") is bool:
		return false
	for key in ["seed", "state"]:
		if not data.get(key) is String or not data[key].is_valid_int() or str(int(data[key])) != data[key]:
			return false
	var candidate = Enemies.new()
	if not candidate.restore(data.get("enemies")) or (data.pending >= 0 and not candidate.is_active(int(data.pending))):
		return false
	var restored_manual
	if data.get("manual") != null:
		restored_manual = Tactical.new()
		if data.pending < 0 or not restored_manual.restore(data.manual) or restored_manual.settled:
			return false
	if data.has("manual_paused") and not data.manual_paused is bool:
		return false
	if restored_manual == null and data.get("manual_paused", false):
		return false
	manual = restored_manual
	manual_paused = data.get("manual_paused", true) if manual != null else false
	enemies = candidate
	difficulty = int(data.difficulty)
	automatic = data.automatic
	pending = int(data.pending)
	rng.seed = int(data.seed)
	rng.state = int(data.state)
	if app != null:
		_sync_options()
	return true
