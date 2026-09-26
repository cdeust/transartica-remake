extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var app = load("res://scripts/main.gd").new()
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/trip-test-save-%s.json" % OS.get_process_id())
	root.add_child(app)
	app.set_process(false)
	await process_frame
	await process_frame
	app._restart_engine()
	app.engine.heat = 2500
	app.engine.pressure_reserve = 15000
	app.engine.regulator = 150
	app.engine.lignite_rate = 1
	app._open_panel("map")
	await process_frame
	for step in 60:
		app._process(1.0)
	_check(app.journey.position.x > 12, "map screen advances real journey")
	_check(app.engine.lignite < 2000, "journey consumes coal")
	_check(app.world_view.discovery.current_position == app.journey.position, "movement reveals current cell")
	app.session.paused = true
	var saved: Dictionary = app.journey.snapshot()
	_check(app.save_view(), "save trip")
	app._restart_engine()
	app._restore_view()
	_check(app.journey.snapshot() == saved, "restore partial journey")
	_check(app.session.paused, "restore pause")
	app._process(5.0)
	_check(app.journey.snapshot() == saved, "paused map does not move")
	app.session.paused = false
	_check(app.engine.speed > 0, "train is rolling before the brake is applied")
	app.engine.brake = true
	var previous_speed: int = app.engine.speed
	var previous_x: float = app.journey.fractional_position().x
	var monotone := true
	for step in 80:
		if app.engine.speed == 0:
			break
		app._process(1.0)
		monotone = monotone and app.engine.speed < previous_speed and app.journey.fractional_position().x >= previous_x
		previous_speed = app.engine.speed
		previous_x = app.journey.fractional_position().x
	_check(monotone, "progressive brake slows each cycle while the train keeps rolling")
	_check(app.engine.speed == 0, "progressive brake brings the train to rest")
	var stopped: Dictionary = app.journey.snapshot()
	app._process(1.0)
	_check(app.journey.snapshot() == stopped, "braked map does not move once stopped")
	_test_station_departure_restore(app)
	_test_city_trade_screen(app)
	_test_workshop_screen(app)
	_test_legacy_route_restore(app)
	_test_invalid_discovery(app)
	app.world_view.selected_city = 0
	app._restart_engine()
	_check(app.world_view.selected_city == -1, "reset clears selected city")
	DirAccess.remove_absolute(app.save_path_override)
	app.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: playable map travel, coal use, fog, brake, pause and saved journey")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func _test_invalid_discovery(app) -> void:
	var current: Dictionary = app.session.snapshot()
	var corrupt: Variant = JSON.parse_string(FileAccess.get_file_as_string(app.save_path_override))
	corrupt.discovery = {"version": 99}
	corrupt.session.engine.lignite = 999
	var file := FileAccess.open(app.save_path_override, FileAccess.WRITE)
	file.store_string(JSON.stringify(corrupt))
	file.close()
	app._restore_view()
	_check(app.session.snapshot() == current, "bad discovery cannot partly restore engine")


func _test_legacy_route_restore(app) -> void:
	app._restart_engine()
	app.session.paused = true
	_check(app.save_view(), "prepare isolated legacy restore fixture")
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(app.save_path_override))
	var active_journey: Dictionary = app.journey.snapshot()
	var active_session: Dictionary = app.session.snapshot()
	var active_network: Dictionary = app.network.snapshot()
	var active_discovery: Dictionary = app.world_view.discovery.snapshot()
	var active_consist: Array = app.world_view.consist.snapshot()
	var legacy: Dictionary = valid.duplicate(true)
	# Owner's pre-route-history checkpoint: current direction cannot recover
	# the entry branch at this tile, so a full train cannot be placed safely.
	legacy.journey = {"version":2,"position":[20,58],"heading":6,"phase":2,"distance_ticks":7,"blocked":false,"stop_reason":""}
	legacy.session.engine.lignite = 777
	var probe = preload("res://scripts/train_journey.gd").new()
	probe.network = app.network
	_check(probe.restore(legacy.journey), "legacy fixture is structurally valid journey data")
	_check(not probe.sample_behind(app.world_view.consist.length_world()).ok, "legacy fixture cannot recover full wagon history")
	_write_fixture(app.save_path_override, legacy)
	var preserved := FileAccess.get_file_as_bytes(app.save_path_override)
	app._restore_view()
	_check(app.journey.snapshot() == active_journey, "ambiguous legacy save cannot replace valid active journey")
	_check(app.session.snapshot() == active_session and app.network.snapshot() == active_network, "rejected wagon history cannot partially restore engine or switches")
	_check(app.world_view.discovery.snapshot() == active_discovery and app.world_view.consist.snapshot() == active_consist, "rejected wagon history preserves discovery and consist")
	_check(app.world_view.train_renderer.poses(app.journey,app.world_view.consist,0.0).size() == 6, "active six-vehicle train remains renderable after rejected restore")
	_check(FileAccess.get_file_as_bytes(app.save_path_override) == preserved, "rejected restore leaves saved file byte-for-byte unchanged")
	_check(app.room_controls.notice == "This save cannot recover wagon positions. Current journey kept; saved file unchanged.", "rejected legacy restore announces actionable reason")
	# Known initial route still migrates from v2; current v3 was tested above.
	var known: Dictionary = valid.duplicate(true)
	known.journey.version = 2
	known.journey.erase("path")
	known.journey.erase("incoming_heading")
	known.session.engine.lignite = 777
	_write_fixture(app.save_path_override, known)
	var known_bytes := FileAccess.get_file_as_bytes(app.save_path_override)
	app._restore_view()
	_check(app.engine.lignite == 777 and app.journey.snapshot() == active_journey, "known-history legacy v2 restores engine and journey")
	_check(app.room_controls.notice == "Journey and engine restored", "accepted legacy restore announces success")
	_check(FileAccess.get_file_as_bytes(app.save_path_override) == known_bytes, "successful legacy migration does not rewrite owner save")


func _write_fixture(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


# A save taken just after leaving a city: the wagons are still inside the
# station (no rail history yet) and the restore must keep the journey.
func _test_station_departure_restore(app) -> void:
	app._restart_engine()
	var cycles := 0
	while not app._city_panel.visible and cycles < 20000:
		app.engine.speed = 450
		app._advance_journey()
		cycles += 1
	_check(app._city_panel.visible, "trip reaches the first city")
	app.depart_from_city()
	_check(not app.journey.sample_behind(app.world_view.consist.length_world()).ok, "wagons are still hidden in the station")
	var departed: Dictionary = app.journey.snapshot()
	_check(app.save_view(), "save just after departure")
	app._restart_engine()
	app._restore_view()
	_check(app.journey.snapshot() == departed, "restore keeps a journey whose wagons are still in the station")
	_check(not app._city_panel.visible, "restored departure does not reopen the city")


# BHOPAL is a mammoth fair (glieu 0xcd1: 250 to buy, wagons of type 7 hold 3).
func _test_city_trade_screen(app) -> void:
	var trade_rules = preload("res://scripts/city_trade.gd")
	app._restart_engine()
	var cycles := 0
	while not app._city_panel.visible and cycles < 20000:
		app.engine.speed = 450
		app._advance_journey()
		cycles += 1
	_check(app._city_panel.visible and app._city_panel.kind == trade_rules.MAMMOTH_FAIR, "BHOPAL opens as a mammoth fair")
	app.engine.speed = 0 # the loop forces 450, beyond the 0..300 range a save accepts
	app._city_panel.start(trade_rules.SELL)
	_check(not app._city_panel.in_transaction() and app._city_panel._notice.text != "", "nothing to sell is refused on entry")
	app.wagons.wagons.append([7, 0, 0, 0])
	app._city_panel.start(trade_rules.BUY)
	_check(app._city_panel.in_transaction(), "a mammoth wagon opens the purchase")
	app._city_panel.handle_key(KEY_EQUAL)
	app._city_panel.handle_key(KEY_EQUAL)
	app._city_panel.handle_key(KEY_ENTER)
	_check(app.engine.lignite == 1500 and app.wagons.wagons[-1] == [7, 0, 0, 2], "two mammoths cost 500 lignite and board")
	_check(app.engine.train_mass == 1346, "mammoths weigh ten each (TIME 0x2b98)")
	_check(not app._city_panel.in_transaction() and app._city_panel.visible, "validation returns to the city menu")
	_check(app.save_view(), "save in the city")
	app._restart_engine()
	_check(app.engine.train_mass == 1266, "restart restores the TABLE train")
	app._restore_view()
	_check(app.wagons.wagons[-1] == [7, 0, 0, 2] and app.engine.train_mass == 1346, "cargo and mass survive save and restore")
	_check(app._city_panel.visible, "restore in a station reopens the city")
	app._city_panel.handle_key(KEY_ENTER)
	_check(not app._city_panel.visible, "Enter in the menu leaves the city")


# glieu 0x1d64..0x21e7: IN SALAH (city 10) opens the workshop instead of a market.
func _test_workshop_screen(app) -> void:
	app._restart_engine()
	var panel = app._city_panel
	panel.open(10, "IN SALAH", 0, "")
	_check(panel.visible and not panel.in_transaction(), "a workshop city opens on its menu")
	panel.start_workshop()
	_check(panel.in_transaction() and panel._list.item_count == 8, "IN SALAH lists eight wagons")
	panel.handle_key(KEY_EQUAL)
	panel.handle_key(KEY_ENTER)
	_check(app.wagons.count() == 6 and app.engine.lignite == 2000, "nothing is bought without a selection")
	panel._select_goods(7) # LIVESTOCK, 300
	panel.handle_key(KEY_EQUAL)
	panel.handle_key(KEY_EQUAL)
	panel.handle_key(KEY_ENTER)
	_check(app.engine.lignite == 1400 and app.wagons.count() == 8 and app.wagons.wagons[-1] == [7, 0, 0, 0], "two livestock wagons cost 600 lignite")
	_check(app.engine.train_mass == 1266 + 120, "bought wagons weigh on the train")
	_check(panel.in_transaction() and panel._entry.is_empty(), "validation stays in the list without a selection")
	panel.handle_key(KEY_ESCAPE)
	_check(panel.visible and not panel.in_transaction(), "exit returns to the workshop menu")
	panel.hide()
