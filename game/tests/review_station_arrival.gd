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
	# Workshop of IN SALAH (city 10), driven by real mouse and key events.
	main._city_panel.leave_transaction()
	main._open_city(10)
	await process_frame
	main._city_panel.start_workshop()
	await process_frame
	var item: Rect2 = main._city_panel._list.get_item_rect(7)
	await _click(main._city_panel._list.get_global_transform() * item.get_center())
	_check(main._city_panel._entry == [7, 300], "a click selects LIVESTOCK at 300")
	for press in 2:
		await _key(KEY_EQUAL)
	_check(main._city_panel._quantity == 2, "two presses of + ask for two wagons")
	await _capture("city-workshop-in-salah.png")
	var lignite: int = main.engine.lignite
	await _key(KEY_ENTER)
	_check(main.engine.lignite == lignite - 600 and main.wagons.count() == 8, "Enter buys two wagons for 600")
	await _capture("city-workshop-in-salah-bought.png")
	if failures.is_empty():
		print("PASS: native station arrival, city screen, departure turn, emerging convoy, trade screen and workshop")
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


func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
		await process_frame


func _key(keycode: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
