extends RefCounted

# Remake JSON v7 schema extracted from main.gd at 653b895. This is not an
# original Amiga save format. Named slots use captain-crew.md book input rules.
const RailNetworkScript = preload("res://scripts/rail_network.gd")
const TrainWagonsScript = preload("res://scripts/train_wagons.gd")
const CityTradeScript = preload("res://scripts/city_trade.gd")
const Extensions = preload("res://scripts/session_save_extensions.gd")


static func snapshot(app) -> Dictionary:
	# The drawn consist is derived from wagons; never persist a second composition.
	var state := {
		"version": 7, "wagons": app.wagons.snapshot(), "trade": app.trade.snapshot(),
		"travel_camera": {"x": app.world_view.camera_world.x, "y": app.world_view.camera_world.y, "follow": app.world_view.following_train, "inspecting": app.world_view.inspecting_map},
		"journey": app.journey.snapshot(), "network": app.network.snapshot(),
		"session": app.session.snapshot(), "discovery": app.world_view.discovery.snapshot(),
		"zoom": app.world_view.zoom, "offset_x": app.world_view.offset.x, "offset_y": app.world_view.offset.y,
		"selected_city": app.world_view.selected_city, "elapsed_seconds": app.clock.elapsed_seconds,
		"calendar": app.calendar.snapshot(), "encounters": app.encounters.snapshot(),
	}
	if _has_stoup(app):
		state.stoup = app.stoup.snapshot()
	Extensions.append_snapshot(app, state)
	return state


static func save(app, path: String) -> Dictionary:
	var failed := {"ok": false, "notice": "Could not save engine session"}
	if path.is_empty() or DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return failed
	# Same-directory rename leaves the prior save intact if write/flush fails.
	var temporary := path + ".tmp-" + str(OS.get_process_id())
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return failed
	file.store_string(JSON.stringify(snapshot(app)))
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		DirAccess.remove_absolute(temporary)
		return failed
	return {"ok": true, "notice": "Engine session saved"}


static func restore(app, path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "notice": ""}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return {"ok": false, "notice": "Save file is invalid; current session kept"}
	var parsed: Dictionary = json.data
	# Named books are produced by snapshot(); legacy view.json keeps optional fields.
	if path.get_extension().to_upper() == "SAV" and not parsed.has("session"):
		return {"ok": false, "notice": "Save file is invalid; current session kept"}
	return _restore_parsed(app, parsed)


static func _restore_parsed(app, parsed: Dictionary) -> Dictionary:
	var base := _stage_base(app, parsed)
	if not base.ok:
		return base
	var notice := _validate_chart(parsed)
	if not notice.is_empty():
		return {"ok": false, "notice": notice}
	for key in ["discovery", "stoup"]:
		var candidate = preload("res://scripts/map_discovery.gd").new() if key == "discovery" else preload("res://scripts/stoup_messages.gd").new()
		if parsed.has(key) and not candidate.restore(parsed[key]):
			return Extensions.failure(key.capitalize() + " save is invalid")
	var extra := Extensions.stage(app, parsed, base)
	if not extra.ok:
		return extra
	return _commit(app, parsed, base, extra.value)


static func _stage_base(app, parsed: Dictionary) -> Dictionary:
	var base := {"ok": true, "network": RailNetworkScript.new(), "wagons": TrainWagonsScript.new(), "trade": CityTradeScript.new(), "encounters": preload("res://scripts/world_encounters.gd").new()}
	base.network.load_bytes(app.world_data.map_bytes)
	base.network.set_city_anchors(app.world_data.city_anchors())
	base.network.campaign_entry_enabled = app.network.campaign_entry_enabled
	base.journey = preload("res://scripts/train_journey.gd").new()
	base.journey.network = base.network
	base.session = preload("res://scripts/engine_session.gd").new(preload("res://scripts/engine_state.gd").new(), app.session.seconds_per_cycle)
	for key in ["network", "journey", "wagons", "trade", "encounters", "session"]:
		if parsed.has(key) and not base[key].restore(parsed[key]):
			return Extensions.failure(key.capitalize() + " save is invalid")
	# Composition derives from cargo, including old v7 saves carrying "consist".
	var consist = preload("res://scripts/train_consist.gd").new()
	consist.derive_from_wagons(base.wagons)
	# PR7 deliberately requires locomotive history: the initial source position
	# can have an incomplete trailing branch; rejecting it would reject new games.
	# Full-route rendering still refuses to invent missing wagon geometry.
	if not base.journey.sample_behind(consist.LENGTHS.locomotive).ok and not base.journey.history_starts_in_station():
		return {"ok": false, "notice": "This save cannot recover wagon positions. Current journey kept; saved file unchanged."}
	return base


static func _commit(app, parsed: Dictionary, base: Dictionary, extra: Dictionary) -> Dictionary:
	app._boudoir_session.city_suspended = false
	if parsed.has("session"):
		app.session.restore(base.session.snapshot())
	if _has_stoup(app):
		app.stoup.restore(parsed.get("stoup", []))
	app.network.restore(base.network.snapshot())
	app.journey.restore(base.journey.snapshot())
	app.encounters.restore(base.encounters.snapshot())
	app.encounters.report.hide()
	app.encounters.manual_scene.hide()
	app.wagons.restore(base.wagons.snapshot())
	if parsed.has("trade"):
		app.trade.restore(base.trade.snapshot())
	else:
		app.trade.reset(app._trade_rng)
	app.engine.train_mass = app.wagons.mass()
	app.world_view.consist.derive_from_wagons(app.wagons)
	app.world_view._visual_initialized = false
	restore_chart(app, parsed)
	app._city_panel.hide()
	Extensions.commit(app, extra)
	app.world_view.visit_cell(app.journey.position)
	if Extensions.blocks(app):
		app.session.paused = true
	elif app.journey.station_result() >= 0:
		# Loading restores the saved visit; it must not reroll nomad stock.
		if app.has_method("_show_city"):
			app._show_city(app.journey.station_result())
		else:
			app._open_city(app.journey.station_result())
	if app.encounters.pending >= 0:
		app.session.paused = true
		app.encounters.resume_pending()
	Extensions.commit_audio(app, extra)
	return {"ok": true, "notice": "Journey and engine restored" if parsed.has("journey") else "Previous engine restored · first journey starts at departure"}


static func _validate_chart(parsed: Dictionary) -> String:
	# Legacy calendar restore intentionally falls back to its initial value.
	# Validate conversion inputs before _restore_chart touches the active app.
	for key in ["zoom", "offset_x", "offset_y", "selected_city", "elapsed_seconds"]:
		if parsed.has(key) and not _number(parsed[key]):
			return "Save file is invalid; current session kept"
	if parsed.has("travel_camera") and not parsed.travel_camera is Dictionary:
		return "Save file is invalid; current session kept"
	if parsed.has("travel_camera"):
		for key in ["x", "y"]:
			if parsed.travel_camera.has(key) and not _number(parsed.travel_camera[key]):
				return "Save file is invalid; current session kept"
		for key in ["follow", "inspecting"]:
			if parsed.travel_camera.has(key) and not parsed.travel_camera[key] is bool:
				return "Save file is invalid; current session kept"
	return ""


static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _has_stoup(app) -> bool:
	for property in app.get_property_list():
		if property.name == "stoup":
			return app.stoup != null
	return false


static func restore_chart(app, parsed: Dictionary) -> void:
	if parsed.has("discovery"):
		app.world_view.discovery.restore(parsed.discovery)
	app._filter_cities(app.search_box.text)
	app.world_view.zoom = clampf(float(parsed.get("zoom", app.world_view.zoom)), preload("res://scripts/travel_world.gd").TRAVEL_MIN_ZOOM, preload("res://scripts/travel_world.gd").TRAVEL_MAX_ZOOM)
	app.world_view.offset = Vector2(float(parsed.get("offset_x", app.world_view.offset.x)), float(parsed.get("offset_y", app.world_view.offset.y)))
	var city_index := int(parsed.get("selected_city", -1))
	app.world_view.selected_city = city_index if city_index >= 0 and city_index < app.world_data.cities.size() and app._city_discovered(city_index) else -1
	app.clock.set_elapsed(float(parsed.get("elapsed_seconds", 0.0)))
	# Saves before the calendar port start at day 1, 00:00 (TABLE 0x0130).
	app.calendar = preload("res://scripts/game_calendar.gd").new()
	if parsed.has("calendar") and not app.calendar.restore(parsed.calendar):
		app.calendar = preload("res://scripts/game_calendar.gd").new()
	app.world_view.inspecting_map = false
	app._map_opened = parsed.has("travel_camera")
	if app._map_opened and parsed.travel_camera is Dictionary:
		app.world_view.camera_world = Vector2(float(parsed.travel_camera.get("x", 12.5)), float(parsed.travel_camera.get("y", 62.5)))
		app.world_view.following_train = bool(parsed.travel_camera.get("follow", false))
		app.world_view.inspecting_map = bool(parsed.travel_camera.get("inspecting", false))
	app.world_view._refresh_discovery_mask()
	if not parsed.has("discovery"):
		app.world_view.fit_discovered()
	app.world_view.queue_redraw()
	app._update_status()
	app.city_list.deselect_all()
	app._select_visible_city()



# Keep the existing main.gd save location for editor and portable exports.
static func default_path() -> String:
	if OS.has_feature("template"):
		var executable_dir := OS.get_executable_path().get_base_dir()
		if OS.has_feature("macos"):
			executable_dir = executable_dir.get_base_dir().get_base_dir().get_base_dir()
		return executable_dir.path_join("save/view.json")
	return ProjectSettings.globalize_path("res://save/view.json")
