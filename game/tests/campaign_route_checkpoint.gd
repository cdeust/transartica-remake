extends RefCounted

# MIT. Production disk serialization of an earned route state. The host below
# supplies presentation callbacks only; gameplay references are the route models.
const Saves = preload("res://scripts/session_saves.gd")

class Chart extends Control:
	var camera_world := Vector2(12.5,62.5)
	var following_train := false
	var inspecting_map := false
	var discovery = preload("res://scripts/map_discovery.gd").new()
	var consist = preload("res://scripts/train_consist.gd").new()
	var zoom := 1.0
	var offset := Vector2.ZERO
	var selected_city := -1
	var _visual_initialized := false
	func visit_cell(_cell: Vector2i) -> void:pass
	func _refresh_discovery_mask() -> void:pass
	func fit_discovered() -> void:pass

class Host extends RefCounted:
	var wagons
	var trade
	var journey
	var network
	var engine
	var session
	var world
	var roamers
	var calendar
	var encounters
	var campaign
	var works_dialog
	var stoup
	var _trade_rng
	var world_data
	var clock = preload("res://scripts/survey_clock.gd").new()
	var world_view = Chart.new()
	var _boudoir_session
	var _city_panel := Control.new()
	var search_box := LineEdit.new()
	var city_list := ItemList.new()
	var _map_opened := false
	func _filter_cities(_value: String) -> void:pass
	func _city_discovered(_index: int) -> bool:return false
	func _update_status() -> void:pass
	func _select_visible_city() -> void:pass
	func _open_city(_index: int) -> void:pass
	func dispose() -> void:
		for node in [world_view,_city_panel,search_box,city_list]:node.free()


static func meaningful(driver) -> Dictionary:
	var value := {"engine":driver.engine.snapshot(),"wagons":driver.wagons.snapshot(),
		"trade":driver.trade.snapshot(),"journey":driver.journey.snapshot(),
		"network":driver.network.snapshot(),"calendar":driver.calendar.snapshot(),
		"campaign":driver.campaign.snapshot(),"world":driver.world.snapshot(),"roamers":driver.roamers.snapshot(),
		"encounters":driver.story_ui.encounters.snapshot(),"stoup":driver.stoup.snapshot(),
		"trade_rng_seed":str(driver.rng.seed),"trade_rng_state":str(driver.rng.state),
		"gates":driver.gates.duplicate(true),"advance_calls":driver.advance_calls,
		"entered_cells":driver.entered_cells}
	# Compare the durable JSON representation, including path coordinates. Godot
	# recomputes path lengths on restore, which can differ below JSON precision.
	return JSON.parse_string(JSON.stringify(value))


static func reload_disk(driver, data, path: String) -> Dictionary:
	var host := Host.new()
	for property in ["wagons","trade","journey","network","engine","world","roamers","calendar","stoup"]:
		host.set(property,driver.get(property))
	host.world_data = data
	host.session = preload("res://scripts/engine_session.gd").new(driver.engine,1.0)
	host.session.paused = driver.story_ui.session.paused
	host._boudoir_session = driver.story_ui._boudoir_session
	host.encounters = driver.story_ui.encounters
	host.campaign = driver.story_ui.campaign_session
	host.works_dialog = driver.dialog
	host._trade_rng = driver.rng
	var before := meaningful(driver)
	var saved := Saves.save(host,path)
	if not saved.ok:
		host.dispose()
		return saved
	# A newly opened application owns a newly randomized commerce RNG. Do not
	# preserve the old object accidentally or transplant its state in the test.
	host._trade_rng = RandomNumberGenerator.new()
	host._trade_rng.randomize()
	var fresh_state := str(host._trade_rng.state)
	# A copy with the omitted field reproduces the legacy omission without
	# changing any earned cargo, quest, position or enemy state in the file.
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	legacy.erase("trade_rng")
	var legacy_file := FileAccess.open(path + ".legacy.SAV",FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()
	var legacy_result := Saves.restore(host,path + ".legacy.SAV")
	if not legacy_result.ok or str(host._trade_rng.state) != fresh_state:
		host.dispose()
		return {"ok":false,"notice":"Legacy RNG-omission control did not retain the fresh process RNG"}
	driver.trace.append("LEGACY SAVE CONTROL: missing commerce RNG retains fresh process state; current save must restore earned RNG")
	var loaded := Saves.restore(host,path)
	if loaded.ok:
		driver.campaign = host.campaign.state
		driver.planner.campaign = host.campaign.state
		driver.enemies = host.encounters.enemies
		driver.encounter_rng = host.encounters.rng
		driver.rng = host._trade_rng
		driver.world.rng = host._trade_rng
		driver.dialog.rng = host._trade_rng
		driver.story_ui._trade_rng = host._trade_rng
		driver.calendar = host.calendar
		driver.story_ui.calendar = host.calendar
		var after := meaningful(driver)
		loaded.ok = after == before
		if not loaded.ok:
			var changed: Array[String] = []
			for name in before:
				if before[name] != after[name]:changed.append(name)
			var output := FileAccess.open(path + ".difference.json",FileAccess.WRITE)
			output.store_string(JSON.stringify({"before":before,"after":after},"\t"))
			output.close()
			loaded.notice = "Earned midpoint differs after disk restore: " + ",".join(changed) + " (fresh RNG " + fresh_state + ")"
	host.dispose()
	return loaded
