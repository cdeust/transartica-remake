extends SceneTree

const Saves = preload("res://scripts/session_saves.gd")
const World = preload("res://scripts/world_encounters.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var app = load("res://scripts/main.gd").new()
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/world-loop-auto.json")
	app.size = Vector2(1280, 800) # Native project viewport fixture.
	root.add_child(app)
	app.set_process(false)
	await process_frame
	await process_frame
	app._restart_engine()
	app.encounters.rng.seed = 901 # source: deterministic regression fixture, not game calibration.
	_check(not app.encounters.automatic and app.encounters.difficulty == 0, "original defaults")
	app.calendar.day = 3
	app.calendar.hour = 23
	app.calendar.minute = 57
	app._advance_calendar()
	_check(app.encounters.enemies.is_active(0), "day4 spawns default-difficulty enemy")
	_test_save(app)
	_test_manual(app)
	_test_automatic(app)
	app.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: calendar enemies, persistent RNG/history, pending encounter, original auto option, victory/defeat, no duplicate loot")
	quit(0 if failures.is_empty() else 1)


func _test_manual(app) -> void:
	app._restart_engine()
	var slot := _place_enemy(app)
	app.session.advance(app.session.seconds_per_cycle * 3)
	_check(app.encounters.pending == slot and app.encounters.manual_scene.visible and app.encounters.manual != null and app.session.paused, "manual encounter opens actual tactical scene")
	_check(app.calendar.minute == 3, "encounter stops catch-up cycles immediately")
	var file_path := ProjectSettings.globalize_path("res://../.cache/world-loop-pending.SAV")
	_check(Saves.save(app, file_path).ok, "pending encounter saved")
	app.encounters.reset()
	_check(Saves.restore(app, file_path).ok and app.encounters.pending == slot and app.encounters.manual != null, "pending tactical state restored once")
	var valid: Dictionary = Saves.snapshot(app)
	var invalid := valid.duplicate(true)
	invalid.encounters.enemies.slots[slot][World.Enemies.STRENGTH] = -1
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(invalid))
	file.close()
	_check(not Saves.restore(app, file_path).ok and Saves.snapshot(app) == valid, "negative enemy strength rejected before mutation")
	DirAccess.remove_absolute(file_path)


func _test_automatic(app) -> void:
	# Future automatic encounters remain separate from an already-running battle.
	app._restart_engine()
	var slot := _place_enemy(app)
	# Arm enough existing cannon wagons for a positive automatic margin.
	app.wagons.wagons.append([11, 0, 0, 0])
	app.wagons.wagons.append([11, 0, 0, 0])
	app.encounters.pending = slot
	app._open_panel("options")
	app.encounters.report.hide()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	var bounds: Rect2 = app._boudoir_session.reception.canvas_rect()
	event.position = bounds.position + Vector2(255, 34) * bounds.size / Vector2(320, 200)
	app._boudoir_session.reception._gui_input(event)
	_check(app.encounters.automatic and app.encounters.report.result.get("won", false), "original combat-option plaque resolves queued encounter")
	_check(not app.encounters.enemies.is_active(slot) and app.encounters.pending == -1, "victory removes enemy once")
	_check(app.engine.train_mass == app.wagons.mass(), "combat changes derived train mass")
	var after: Array = app.wagons.snapshot()
	app.encounters.resolve_pending()
	_check(app.wagons.snapshot() == after, "no duplicate loot")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ENTER
	key.pressed = true
	app._unhandled_key_input(key)
	_check(not app.session.paused and not app.encounters.report.visible, "report Return resumes travel")
	app._restart_engine()
	_place_enemy(app, 32700)
	app.session.advance(app.session.seconds_per_cycle)
	_check(not app.encounters.report.result.get("won", true) and app.session.paused, "defeat stops game")
	app._unhandled_key_input(key)
	_check(app._boudoir_session.reception.visible and app.session.paused, "defeat returns to options")


func _place_enemy(app, strength := 0) -> int:
	var enemies = app.encounters.enemies
	var slot: int = enemies.spawn(0, app.encounters.rng)
	var state: Dictionary = enemies.snapshot()
	state.slots[slot][enemies.DX] = app.journey.position.x - 40
	state.slots[slot][enemies.Y] = app.journey.position.y
	state.slots[slot][enemies.SPEED] = 0
	state.slots[slot][enemies.STRENGTH] = strength
	_check(enemies.restore(state), "encounter fixture on actual player tile")
	return slot


func _test_save(app) -> void:
	var state: Dictionary = app.encounters.snapshot()
	state.enemies.switch_history = [[152, 66], [151, 66]] # Source: scripted route coordinates.
	var copy = World.new()
	_check(copy.restore(state), "restore world snapshot")
	_check(copy.enemies.snapshot().switch_history == state.enemies.switch_history, "switch history survives restore")
	_check(copy.rng.randi() == app.encounters.rng.randi(), "RNG resumes exactly")
	var invalid := state.duplicate(true)
	invalid.enemies.slots[0][World.Enemies.HEADING] = 0
	var before := copy.snapshot()
	_check(not copy.restore(invalid) and copy.snapshot() == before, "invalid enemy rejected transactionally")
	invalid = state.duplicate(true)
	invalid.state = "9223372036854775808"
	_check(not copy.restore(invalid), "overflowed RNG state rejected")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
