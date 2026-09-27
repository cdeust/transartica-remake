extends SceneTree

# Native review of the 38-58 track glyphs on the owner's reported stretch:
# the fast line of row 59 and the curves up to (49,55). Run with a window:
#   Godot --path game --script res://tests/review_rail_glyphs.gd
# Captures land in tasks/validation/; the save file stays in .cache/.

const CAPTURE_DIR := "res://../tasks/validation/"
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	main.save_path_override = ProjectSettings.globalize_path("res://../.cache/review-rails/view.json")
	root.add_child(main)
	for frame in 3:
		await process_frame
	main._open_panel("map")
	await process_frame
	var start := {"version": 1, "position": [36, 59], "heading": 6, "distance_ticks": 0, "phase": 0, "blocked": false}
	_check(main.journey.restore(start), "journey placed on the row 59 fast line")
	main.world_view.following_train = true
	await _drive_until(main, func(): return main.journey.position == Vector2i(42, 59))
	_check(main.journey.position == Vector2i(42, 59), "train reaches (42,59) eastbound")
	await _capture("rails-fast-line-row59.png")
	await _drive_until(main, func(): return main.journey.position == Vector2i(49, 55))
	_check(main.journey.position == Vector2i(49, 55), "train climbs the curves to (49,55)")
	await _capture("rails-curves-49-55.png")
	if failures.is_empty():
		print("PASS: native review of tracks 38-58 on row 59 and the (48,59)-(49,55) curves")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _drive_until(main, done: Callable) -> void:
	var cycles := 0
	while not done.call() and not main.journey.blocked and cycles < 4000:
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


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
