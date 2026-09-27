extends SceneTree

# Native review of track works (tasks/evidence/obstacles.md): the intact crevasse bridge
# at (83,67), then a destroyed cell ahead with the YODA 0x2390 question, YES by mouse,
# and the train crossing the repaired cell. Run with a window:
#   Godot --path game --script res://tests/review_track_works.gd
# Destroyed track only appears at runtime (CARTE 0x2852), so the review writes one cell.

const CAPTURE_DIR := "res://../tasks/validation/"
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	main.save_path_override = ProjectSettings.globalize_path("res://../.cache/review-works/view.json")
	root.add_child(main)
	for frame in 3:
		await process_frame
	main._open_panel("map")
	await process_frame
	var start := {"version": 1, "position": [78, 67], "heading": 6, "distance_ticks": 0, "phase": 0, "blocked": false}
	_check(main.journey.restore(start), "journey placed west of the (83,67) bridge")
	await _drive_until(main, func(): return main.journey.position == Vector2i(84, 67))
	_check(main.journey.position == Vector2i(84, 67), "train crosses the intact crevasse bridge (83,67)")
	await _capture("works-bridge-83-67.png")
	var broken := Vector2i(88, 67)
	main.network._tiles[broken.x * main.network.HEIGHT + broken.y] = -2
	main.wagons.wagons.append([17, 0, 1, 12])
	main.wagons.wagons.append([5, 0, 0, 6])
	await _drive_until(main, func(): return main.works_dialog.visible)
	_check(main.works_dialog.visible and main.journey.next_cell() == broken, "question opens before the destroyed cell")
	await _capture("works-question-destroyed.png")
	await _click(main.works_dialog._yes.get_global_rect().get_center())
	_check(main.network.tile(broken) == 2 and main.wagons.wagons[-2][3] == 10, "YES repairs the cell with 2 rails")
	await _capture("works-repaired.png")
	await _click(main.works_dialog._ok.get_global_rect().get_center())
	main.session.paused = false
	main.engine.brake = false
	await _drive_until(main, func(): return main.journey.position.x > broken.x)
	_check(main.journey.position.x > broken.x, "train crosses the repaired cell")
	if failures.is_empty():
		print("PASS: native intact bridge, destroyed-track question, mouse YES, repair and crossing")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _drive_until(main, done: Callable) -> void:
	var cycles := 0
	while not done.call() and cycles < 4000:
		if main.journey.blocked and not main.journey.at_obstacle():
			break
		main.engine.speed = 120
		main._advance_journey()
		cycles += 1
	main.world_view._snap_visual_position(main.world_view._current_journey_position())
	main.world_view.update_train()


func _capture(file_name: String) -> void:
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(CAPTURE_DIR + file_name))


# Events go straight to the viewport in one frame, so the real OS cursor cannot
# interleave a motion event between press and release.
func _click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event)
	for frame in 2:
		await process_frame


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
