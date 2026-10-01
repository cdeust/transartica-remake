extends SceneTree
# requires-native-renderer
# Source: native AudioStreamWAV playback; Dummy mixer leaks measured in cadence review.

# Integration fixtures use actual reference mine cells and source event tile65.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var app = preload("res://scripts/main.gd").new()
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/world-session.SAV")
	app.size = Vector2(1280, 800) # source: project viewport test fixture.
	root.add_child(app)
	app.set_process(false)
	await process_frame
	app._restart_engine()
	app.world.tick_mines(3) # source: YODA day3 mine update.
	var cell: Vector2i = app.world.mines.mine_cell(app.world.mines.records[0])
	app.journey.position = cell - Vector2i(1, 0)
	app.journey.heading = 6
	app.journey.blocked = true
	app.journey.stop_reason = "event site"
	_check(app._world_session.handle_boundary(), "mine boundary routed to live scene")
	_check(app._world_session.mine_screen.visible and app.session.paused, "mine pauses motion")
	app._world_session._answer_mine(false)
	_check(not app._world_session.mine_screen.visible and app.network.tile(cell) == 78, "NO preserves mine")
	app._world_session.handle_boundary()
	app._world_session._answer_mine(true)
	_check(app.network.tile(cell) == 78 and app.world.mine_accepted, "YES waits for dismissal")
	app._world_session._close_mine()
	_check(app.network.tile(cell) == 79 and not app.journey.blocked and app.journey.heading == 4, "dismiss commits mine and reverse exactly once")
	var heading: int = app.journey.heading
	app._world_session._close_mine()
	_check(app.journey.heading == heading, "second dismissal cannot reverse again")
	# Source slope trigger requires imminent phase3; a parked neighbour is inert.
	app.journey.position = Vector2i(153, 47)
	app.journey.heading = 1
	app.journey.phase = 2
	app.engine.speed = 0
	_check(not preload("res://scripts/journey_session.gd")._entry_due(app), "parked beside slope cannot trigger story")
	app.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: live world mine boundary, NO/YES/dismiss ordering, exactly-once reversal and parked story guard")
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
