extends SceneTree

# Native review of the station arrival (TIME message 76) and the departure turn
# (yoda 0x18e3). Run with a window, not headless:
#   Godot --path game --script res://tests/review_station_arrival.gd
# Captures land in tasks/validation/; the save file stays in .cache/.

const CAPTURE_DIR := "res://../tasks/validation/"
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	main.save_path_override = ProjectSettings.globalize_path("res://../.cache/review-station/view.json")
	root.add_child(main)
	for frame in 3:
		await process_frame
	main._open_panel("map")
	await process_frame
	main.world_view.following_train = true
	var cycles := 0
	while not main._city_panel.visible and cycles < 20000:
		main.engine.speed = 450
		main._advance_journey()
		cycles += 1
	_check(main._city_panel.visible, "city screen opens on arrival")
	_check(main._city_panel.city_name == "BHOPAL", "first route arrives at BHOPAL")
	_check(main.session.paused and not main.engine.brake, "arrival pauses travel without the invented brake")
	main.world_view.update_train()
	await _capture("station-arrival-bhopal.png")
	main.depart_from_city()
	_check(not main._city_panel.visible and main.engine.speed == 0, "departure closes the city and zeroes speed")
	_check(main.journey.heading == 4, "train heading reversed from east to west")
	main.world_view.update_train()
	await _capture("station-departure-emerging.png")
	for step in 14:
		main.engine.speed = 450
		main._advance_journey()
	main.world_view._snap_visual_position(main.world_view._current_journey_position())
	main.world_view.update_train()
	await _capture("station-departure-leaving.png")
	# Trade screen of a commercial city, opened directly for review (no route to KUWAIT here).
	main._open_city(24)
	main._city_panel.start(50)
	main._city_panel._list.select(0)
	main._city_panel._select_goods(0)
	for press in 3:
		main._city_panel.increment()
	_check(main._city_panel._quantity == 3, "three units of the first KUWAIT goods can be bought")
	await _capture("city-trade-kuwait.png")
	if failures.is_empty():
		print("PASS: native station arrival, city screen, departure turn, emerging convoy and trade screen")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _capture(file_name: String) -> void:
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(CAPTURE_DIR + file_name))


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
