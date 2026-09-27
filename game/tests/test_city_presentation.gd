extends SceneTree

const CityScreen = preload("res://scripts/city_screen.gd")
const Trade = preload("res://scripts/city_trade.gd")
const Wagons = preload("res://scripts/train_wagons.gd")
const EngineScript = preload("res://scripts/engine_state.gd")
var failures: Array[String] = []
var departed := false
var cargo_events := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = root.size
	var screen := CityScreen.new()
	screen.trade = Trade.new()
	if not screen.trade.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")):
		push_error("FAIL: private commerce fixture missing")
		quit(1)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 # source: fixed reproducible commerce fixture shared with test_city_trade.
	screen.trade.reset(rng)
	screen.wagons = Wagons.new()
	screen.engine = EngineScript.new()
	screen.depart_requested.connect(func(): departed = true; screen.hide())
	screen.cargo_changed.connect(func(): cargo_events += 1)
	root.add_child(screen)
	await process_frame
	await _test_scenes(screen)
	await _test_commerce(screen)
	await _test_workshop(screen)
	screen.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: six visible city scenes, ECS regions, viewport resizing, native trade clicks, workshop and departure")
	quit(0 if failures.is_empty() else 1)


func _test_scenes(screen: Control) -> void:
	var cases := [[17, 1, "city-information"], [24, 2, "city-trading-station"],
		[10, 3, "city-industrial-workshop"], [8, 4, "city-garrison"],
		[0, 5, "city-mammoth-fair"], [5, 6, "city-slave-market"]]
	for viewport in [Vector2i(1280, 800), Vector2i(960, 540), Vector2i(640, 800)]:
		root.size = viewport
		root.content_scale_size = viewport
		await process_frame
		for fixture in cases:
			screen.open(fixture[0], String(fixture[2]).to_upper(), fixture[1], "")
			await process_frame
			await process_frame
			_check(screen.visible and screen.backdrop.texture != null, "City scene is visible with loaded art")
			_check(screen.backdrop.asset_path.ends_with(fixture[2] + ".png"), "City kind selects its matching scene")
			var picture: Rect2 = screen.backdrop.screen_rect(Rect2(0, 39, 320, 110))
			_check(Rect2(Vector2.ZERO, screen.size).encloses(picture), "City picture remains inside viewport")
			_check(not screen._has_point(screen.backdrop.screen_rect(Rect2(160, 180, 1, 1)).position), "City leaves common lower menu clickable")
			var banner: Rect2 = screen.backdrop.screen_rect(Rect2(0, 20, 320, 19))
			for button in screen._menu.get_children():
				_check(banner.encloses(Rect2(button.global_position, button.size)), "City menu stays in original banner")
			if viewport == Vector2i(1280, 800):
				await _capture(screen, fixture[2])
	root.size = Vector2i(1280, 800)
	root.content_scale_size = root.size
	await process_frame


func _test_commerce(screen: Control) -> void:
	screen.open(24, "KUWAIT", Trade.COMMERCIAL, "COMMERCIAL")
	await process_frame
	await process_frame
	await _click(screen._menu.get_child(0))
	_check(screen.in_transaction(), "Buy menu click opens transaction")
	var index := -1
	for i in range(screen._rows.size()):
		if screen._rows[i][0] == 1:
			index = i
	_check(index >= 0, "KUWAIT fixture offers rails")
	if index < 0:
		return
	var selected: Rect2 = screen._list.get_item_rect(index)
	await _click_point(screen._list.global_position + selected.get_center())
	var stock_before: int = screen.trade.stock[0][0]
	await _click(screen._transaction_controls.get_child(3))
	await _click(screen._transaction_controls.get_child(3))
	_check(screen._quantity == 2, "Plus clicks choose two rails")
	await _capture(screen, "city-trade-kuwait")
	await _click(screen._transaction_controls.get_child(0))
	_check(screen.engine.lignite == 1992, "Existing KUWAIT price remains four lignite per rail")
	_check(screen.wagons.wagons[4] == [17, 0, 1, 2], "Existing loading rule puts rails in goods wagon")
	_check(screen.trade.stock[0][0] == stock_before - 2 and cargo_events == 1, "Existing stock update and cargo signal preserved")
	await _click(screen._transaction_controls.get_child(4))
	_check(not screen.in_transaction() and screen.visible, "Transaction EXIT returns to city scene")
	await _click(screen._menu.get_child(screen._menu.get_child_count() - 1))
	_check(departed and not screen.visible, "City EXIT requests departure")


func _test_workshop(screen: Control) -> void:
	screen.open(10, "IN SALAH", 3, "INDUSTRIAL")
	await process_frame
	await process_frame
	await _click(screen._menu.get_child(0))
	_check(screen.in_transaction() and screen._list.item_count == 8, "Workshop scene preserves eight existing offers")
	screen._select_goods(7) # source: existing IN SALAH livestock wagon offer, 300 lignite.
	screen.handle_key(KEY_EQUAL)
	screen.handle_key(KEY_ENTER)
	_check(screen.wagons.count() == 7 and screen.engine.lignite == 1692, "Workshop purchase preserves cost and wagon creation")
	screen.handle_key(KEY_ESCAPE)
	_check(screen.visible and not screen.in_transaction(), "Workshop exit returns to city menu")


func _click(control: Control) -> void:
	await _click_point(control.global_position + control.size / 2.0)


func _click_point(position: Vector2) -> void:
	for pressed in [true, false]:
		var motion := InputEventMouseMotion.new()
		motion.position = position
		motion.global_position = position
		root.push_input(motion, true)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await process_frame


func _capture(_screen: Control, name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.cache/" + name + ".png"))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
