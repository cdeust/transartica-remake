extends RefCounted

# source: enemy-trains.md §6, combat.md §9 and manual.txt lines264–266.
const Enemies = preload("res://scripts/enemy_trains.gd")
const Report = preload("res://scripts/combat_report.gd")
var enemies = Enemies.new()
var rng := RandomNumberGenerator.new()
var difficulty := 0 # source: TABLE0x249 new-game difficulty.
var automatic := false # source: TABLE0x255 combat enabled by default.
var pending := -1
var app
var report


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
	_sync_options()


func reset() -> void:
	enemies.reset()
	pending = -1
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
		enemies.advance_cycle(app.network, rng, app.journey.heading)
		encountered = enemies.encounter_at(app.journey.position)
	if encountered < 0:
		return false
	pending = encountered
	app.session.paused = true
	app._open_panel("room")
	if automatic:
		resolve_pending()
	else:
		report.open_report({"manual": true})
	return true


func resolve_pending() -> void:
	if pending < 0 or not automatic:
		return
	var result: Dictionary = load("res://scripts/automatic_combat.gd").resolve(app.wagons, app.engine, enemies.slots[pending][Enemies.STRENGTH], rng)
	if result.won:
		enemies.remove(pending)
	pending = -1
	app._on_cargo_changed()
	app.session.paused = true
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
	if automatic and pending >= 0:
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
	return {"version": 1, "enemies": enemies.snapshot(), "difficulty": difficulty,
		"automatic": automatic, "pending": pending, "seed": str(rng.seed), "state": str(rng.state)}


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
	enemies = candidate
	difficulty = int(data.difficulty)
	automatic = data.automatic
	pending = int(data.pending)
	rng.seed = int(data.seed)
	rng.state = int(data.state)
	if app != null:
		_sync_options()
	return true
