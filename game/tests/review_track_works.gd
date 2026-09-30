extends SceneTree

# Native review of track works (tasks/evidence/obstacles.md, obstacles-unknowns.md) at the
# real crevasse (83,67): question, NO, re-ask after brake release, OK by mouse, bridge 63
# and crossing. Run with a window:
#   Godot --path game --script res://tests/review_track_works.gd

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
	_check(main.journey.restore(start), "journey placed west of the (83,67) crevasse")
	var crevasse := Vector2i(83, 67)
	await _drive_until(main, func(): return main.works_dialog.visible)
	_check(main.works_dialog.visible and main.journey.next_cell() == crevasse and main.engine.brake, "crevasse question brakes the train")
	await _capture("works-question-crevasse.png")
	await _click(main.works_dialog._no.get_global_rect().get_center())
	_check(not main.works_dialog.visible and main.journey.at_obstacle() and main.network.tile(crevasse) == 67, "NO keeps the train blocked and the crevasse unchanged")
	for cycle in 20:
		main._advance_journey()
	_check(not main.works_dialog.visible, "no new question while braked")
	main.engine.brake = false
	await _drive_until(main, func(): return main.works_dialog.visible)
	_check(main.works_dialog.visible, "question asked again after the brake is released")
	main.wagons.wagons.append([18, 0, 1, 25])
	main.wagons.wagons.append([6, 0, 0, 20])
	await _click(main.works_dialog._yes.get_global_rect().get_center())
	var rails_left: int = main.wagons.wagons[-2][3]
	_check(main.network.tile(crevasse) == 67 and rails_left >= 5 and rails_left <= 9, "OK spends 16-20 rails; map stays blocked during works")
	await _capture("works-bridge-built.png")
	await _click(main.works_dialog._ok.get_global_rect().get_center())
	_check(main.network.tile(crevasse) == 63, "closing TEXTEK commits the bridge")
	_check(main.engine.brake, "brake stays on after the works")
	main.engine.brake = false
	await _drive_until(main, func(): return main.journey.position.x > crevasse.x)
	_check(main.journey.position.x > crevasse.x, "train crosses the new bridge")
	await _capture("works-bridge-crossed.png")
	if failures.is_empty():
		print("PASS: native crevasse question, NO, re-ask after brake release, OK, bridge and crossing")
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
