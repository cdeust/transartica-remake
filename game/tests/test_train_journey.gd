extends SceneTree

const EngineState = preload("res://scripts/engine_state.gd")
const EngineSession = preload("res://scripts/engine_session.gd")
const TrainJourney = preload("res://scripts/train_journey.gd")
const RailNetwork = preload("res://scripts/rail_network.gd")
const WorldData = preload("res://scripts/world_data.gd")
const TrackWorks = preload("res://scripts/track_works.gd")
const TrainWagons = preload("res://scripts/train_wagons.gd")
const GameCalendar = preload("res://scripts/game_calendar.gd")

const CREVASSE := Vector2i(83, 67) # CARTE.FIC 67 on the first eastbound route.

var map_bytes := PackedByteArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var world = WorldData.new()
	if not world.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")):
		push_error("private reference map unavailable")
		quit(1)
		return
	map_bytes = world.map_bytes
	_test_legacy_route(failures)
	_test_path_samples(failures)
	_test_visual_curve(failures)
	_test_initial_progress(failures)
	_test_engine_session_drives_movement(failures)
	_test_pause_and_brake(failures)
	_test_decoded_heading_rules(failures)
	_test_initial_route(failures)
	_test_switch_changes_route(failures)
	_test_destroyed_track_blocks(failures)
	_test_track_works(failures)
	_test_calendar_and_timed_bridge(failures)
	_test_snapshot_and_validation(failures)
	_test_network_snapshot(failures)
	_test_station_lookup(world, failures)
	_test_station_departure(world, failures)
	if failures.is_empty():
		print("PASS: decoded rail network, curves, switches, double-speed tiles, boundaries, stations, persistence")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _network() -> RailNetwork:
	var network := RailNetwork.new()
	network.load_bytes(map_bytes)
	return network


func _journey(network = null) -> TrainJourney:
	var journey := TrainJourney.new()
	journey.network = network if network != null else _network()
	return journey


func _synthetic(cells: Dictionary) -> RailNetwork:
	var bytes := PackedByteArray()
	bytes.resize(RailNetwork.WIDTH * RailNetwork.HEIGHT)
	for cell in cells:
		var value: int = cells[cell]
		bytes[cell.x * RailNetwork.HEIGHT + cell.y] = value + 256 if value < 0 else value
	var network := RailNetwork.new()
	network.load_bytes(bytes)
	network.reset()
	return network


func _test_initial_progress(failures: Array[String]) -> void:
	var detached := TrainJourney.new()
	detached.advance(450)
	_check(detached.distance_ticks == 0, "journey without a network does not move", failures)
	var journey := _journey()
	_check(journey.position == Vector2i(12, 62) and journey.heading == 6, "starts at the original position heading east", failures)
	journey.advance(0)
	journey.advance(-1)
	_check(journey.distance_ticks == 0, "nonpositive speed does not move", failures)
	journey.advance(450)
	_check(journey.distance_ticks == 22 and journey.phase == 0, "capped speed divided by twenty, strict threshold", failures)
	journey.advance(450)
	_check(journey.distance_ticks == 21 and journey.phase == 1, "subtracts 23 ticks and advances one phase above 22", failures)
	# Constant rate over the three phases: 23 + 21 of 69 ticks, cell center at 0.5.
	_check(is_equal_approx(journey.fractional_position().x, 12.0 + (23.0 + 21.0) / 69.0 - 0.5), "interpolates along the heading", failures)


func _test_engine_session_drives_movement(failures: Array[String]) -> void:
	var large_engine = EngineState.new()
	var small_engine = EngineState.new()
	large_engine.speed = 450
	small_engine.speed = 450
	var large_journey := _journey()
	var small_journey := _journey()
	var large_session = EngineSession.new(large_engine, 0.5)
	var small_session = EngineSession.new(small_engine, 0.5)
	large_session.cycle_completed.connect(func() -> void: large_journey.advance(large_engine.speed))
	small_session.cycle_completed.connect(func() -> void: small_journey.advance(small_engine.speed))
	large_session.advance(60.0)
	for frame in 240:
		small_session.advance(0.25)
	_check(large_journey.snapshot() == small_journey.snapshot(), "journey is independent of frame batching (15/60 FPS equivalent)", failures)


func _test_pause_and_brake(failures: Array[String]) -> void:
	var engine = EngineState.new()
	engine.speed = 450
	var journey := _journey()
	var session = EngineSession.new(engine, 1.0)
	session.cycle_completed.connect(func() -> void: journey.advance(engine.speed))
	session.paused = true
	session.advance(5.0)
	_check(engine.cycles == 0 and journey.distance_ticks == 0, "pause prevents movement", failures)
	var braked = EngineState.new()
	braked.brake = true
	var braked_journey := _journey()
	var braked_session = EngineSession.new(braked, 1.0)
	braked_session.cycle_completed.connect(func() -> void: braked_journey.advance(braked.speed))
	braked_session.advance(3.0)
	_check(braked.cycles == 3 and braked_journey.distance_ticks == 0, "stationary braked train does not move", failures)


func _test_decoded_heading_rules(failures: Array[String]) -> void:
	var network := _synthetic({Vector2i(5, 5): 6, Vector2i(6, 5): 22, Vector2i(7, 5): 23, Vector2i(8, 5): 15, Vector2i(9, 5): 40})
	_check(network.turn(Vector2i(5, 5), 6) == 3 and network.turn(Vector2i(5, 5), 7) == 4, "curve tile 6: east to south-east, north-west to west", failures)
	_check(network.turn(Vector2i(5, 5), 2) == 2, "curve keeps unrelated headings", failures)
	_check(network.turn(Vector2i(6, 5), 6) == 6 and network.turn(Vector2i(7, 5), 6) == 3, "switch 22 straight, 23 diverges south-east", failures)
	_check(network.turn(Vector2i(6, 5), 7) == 4, "trailing move through switch 22 rejoins westward", failures)
	_check(network.progress_speed(Vector2i(8, 5), 6, 100) == 200 and network.progress_speed(Vector2i(8, 5), 2, 100) == 100, "tile 15 doubles progress only along 4/6", failures)
	_check(network.progress_speed(Vector2i(9, 5), 8, 100) == 200, "tiles 38-52 double progress", failures)
	_check(network.toggle_switch(Vector2i(6, 5)) and network.tile(Vector2i(6, 5)) == 23, "click on even switch adds one", failures)
	_check(network.toggle_switch(Vector2i(6, 5)) and network.tile(Vector2i(6, 5)) == 22, "click on odd switch subtracts one", failures)
	_check(not network.toggle_switch(Vector2i(5, 5)), "non-switch tiles cannot be toggled", failures)


func _drive(journey: TrainJourney, limit: int) -> Array[Vector2i]:
	var visited: Array[Vector2i] = [journey.position]
	for cycle in limit:
		journey.advance(450)
		if visited[-1] != journey.position:
			visited.append(journey.position)
		if journey.blocked:
			break
	return visited


func _test_initial_route(failures: Array[String]) -> void:
	var journey := _journey()
	var visited := _drive(journey, 20000)
	# No TABLE bridge writes in a normal game: the (83,67) crevasse blocks the first route.
	_check(journey.at_obstacle() and journey.position == Vector2i(82, 67) and journey.next_cell() == CREVASSE, "first route stops before the (83, 67) crevasse", failures)
	_check(journey.network.repair(CREVASSE) and journey.resume_after_works(), "a built bridge reopens the route", failures)
	visited.append_array(_drive(journey, 20000))
	_check(Vector2i(34, 62) in visited, "crosses the (34, 62) crossing that bounded the trial route", failures)
	_check(Vector2i(40, 63) in visited and Vector2i(44, 67) in visited, "curve at (39, 62) turns onto the south-east diagonal", failures)
	_check(Vector2i(45, 67) in visited and Vector2i(130, 68) in visited, "curve at (44, 67) resumes eastward", failures)
	_check(journey.blocked and journey.position == Vector2i(130, 68) and journey.stop_reason == "station", "stops before the unported station tile at (131, 68)", failures)
	_check(journey.next_cell() == Vector2i(131, 68), "reports the refused cell", failures)
	var stopped := journey.snapshot()
	journey.advance(450)
	_check(journey.snapshot() == stopped, "boundary prevents further movement", failures)
	var never_off_track := true
	for cell in visited:
		never_off_track = never_off_track and journey.network.tile(cell) != 0
	_check(never_off_track, "every visited cell holds track", failures)
	journey.reset()
	_check(journey.position == Vector2i(12, 62) and not journey.blocked and journey.stop_reason.is_empty(), "reset clears the journey", failures)


func _test_switch_changes_route(failures: Array[String]) -> void:
	var network := _network()
	_check(network.tile(Vector2i(54, 67)) == 22, "(54, 67) is a straight-set switch at game start", failures)
	network.toggle_switch(Vector2i(54, 67))
	var journey := _journey(network)
	var visited := _drive(journey, 20000)
	_check(Vector2i(55, 68) in visited and not Vector2i(55, 67) in visited, "diverging switch sends the train south-east", failures)
	_check(journey.blocked and journey.next_cell() == Vector2i(138, 71), "diverging branch reaches a different station", failures)


func _test_destroyed_track_blocks(failures: Array[String]) -> void:
	var cells := {}
	for x in range(10, 16):
		cells[Vector2i(x, 62)] = 2
	cells[Vector2i(16, 62)] = -50
	var journey := _journey(_synthetic(cells))
	journey.position = Vector2i(10, 62)
	_drive(journey, 500)
	_check(journey.blocked and journey.position == Vector2i(15, 62) and journey.stop_reason == "obstacle", "negative track tile refuses entry", failures)


func _test_track_works(failures: Array[String]) -> void:
	_check(TrackWorks.kind_for(67) == "crevasse" and TrackWorks.kind_for(-116) == "lake" and TrackWorks.kind_for(-50) == "destroyed", "obstacle kinds from TIME codes", failures)
	_check(TrackWorks.kind_for(-120) == "" and TrackWorks.kind_for(-105) == "", "intact bridge and specials are not works", failures)
	_check(TrackWorks.repaired_code(69) == 64 and TrackWorks.repaired_code(114) == -117 and TrackWorks.repaired_code(-50) == 50, "YODA repair writes", failures)
	var wagons = TrainWagons.new()
	_check(TrackWorks.shortage("destroyed", wagons) == "rails", "start train has no rails", failures)
	wagons.wagons = [[1, 0, 0, 0], [17, 0, 1, 3], [18, 0, 1, 20], [5, 0, 0, 16]]
	_check(TrackWorks.shortage("crevasse", wagons) == "", "23 rails and 16 slaves allow a crevasse bridge", failures)
	wagons.wagons[3][3] = 14
	_check(TrackWorks.shortage("crevasse", wagons) == "slaves", "slaves checked after rails", failures)
	var used := TrackWorks.consume_rails(wagons, 5)
	_check(used == 5 and wagons.wagons[1] == [17, 0, 0, 0] and wagons.wagons[2][3] == 18, "rails taken in wagon order, emptied wagon loses goods", failures)
	var rng := RandomNumberGenerator.new()
	for draw in 50:
		var amount := TrackWorks.rails_needed("lake", rng)
		if amount < 21 or amount > 25:
			failures.append("lake consumption %d outside 21..25" % amount)
	_check(TrackWorks.rails_needed("destroyed", rng) == 2, "destroyed track uses 2 rails", failures)
	var cells := {}
	for x in range(10, 16):
		cells[Vector2i(x, 62)] = 2
	cells[Vector2i(16, 62)] = -50
	var network = _synthetic(cells)
	var journey := _journey(network)
	journey.position = Vector2i(10, 62)
	_drive(journey, 500)
	_check(journey.at_obstacle() and network.repair(journey.next_cell()) and journey.resume_after_works(), "repair unblocks the obstacle", failures)
	_drive(journey, 500)
	_check(journey.position.x > 16 or journey.position == Vector2i(16, 62), "train crosses the repaired cell", failures)
	var saved: Dictionary = network.snapshot()
	var reloaded = _synthetic(cells)
	_check(reloaded.restore(saved) and reloaded.tile(Vector2i(16, 62)) == 50, "repaired cell persists", failures)
	saved.switches["16,62"] = 3
	_check(not reloaded.restore(saved), "arbitrary map change is refused", failures)
	var bridge_cells := {Vector2i(14, 62): 2, Vector2i(15, 62): -121, Vector2i(16, 62): 2}
	_check(_synthetic(bridge_cells).entry_boundary(Vector2i(15, 62)) == "", "intact lake bridge -121 is passable", failures)
	bridge_cells[Vector2i(15, 62)] = -119
	_check(_synthetic(bridge_cells).entry_boundary(Vector2i(15, 62)) == "special site", "other codes <= -105 stay a frontier", failures)


func _test_calendar_and_timed_bridge(failures: Array[String]) -> void:
	var calendar = GameCalendar.new()
	_check(calendar.display_text() == "DAY 1 00:00" and calendar.bridge_code() == -120, "TABLE 0x0130: day 1, 00:00, bridge closed", failures)
	var events: Array[String] = []
	for cycle in 240:
		events.append_array(calendar.advance_cycle())
	_check(calendar.hour == 12 and calendar.minute == 0 and events == ["bridge_open"], "240 cycles of 3 minutes reach 12:00 and open the bridge", failures)
	for cycle in 40:
		events.append_array(calendar.advance_cycle())
	_check(calendar.hour == 14 and events[-1] == "bridge_closed" and calendar.bridge_code() == -120, "the bridge closes at 14:00", failures)
	calendar.factor = GameCalendar.FAST_FACTOR
	for cycle in 200:
		events.append_array(calendar.advance_cycle())
	_check(calendar.day == 2 and calendar.hour == 0 and "new_day" in events, "fast clock keeps 3 minutes per cycle and rolls the day", failures)
	var restored = GameCalendar.new()
	_check(restored.restore(calendar.snapshot()) and restored.display_text() == calendar.display_text(), "calendar survives save", failures)
	_check(not restored.restore({"minute": 60, "hour": 0, "day": 1, "factor": 1}), "invalid minute refused", failures)
	var cells := {Vector2i(10, 62): 2, Vector2i(11, 62): 2, Vector2i(12, 62): 2, Vector2i(13, 62): -120}
	var network = _synthetic(cells)
	var journey := _journey(network)
	journey.position = Vector2i(10, 62)
	_drive(journey, 500)
	_check(journey.at_reversal_event() and journey.next_cell() == Vector2i(13, 62), "closed bridge -120 stops the train", failures)
	_check(journey.depart_from_station() and journey.heading == 4 and not journey.blocked, "YODA 0x18e3 reversal at the closed bridge", failures)
	var timed := {Vector2i(109, 33): 2, Vector2i(110, 33): -120, Vector2i(111, 33): 2}
	var bridge_network = _synthetic(timed)
	_check(bridge_network.set_timed_bridge(-121) and bridge_network.entry_boundary(Vector2i(110, 33)) == "", "open bridge -121 is passable", failures)
	var reloaded = _synthetic(timed)
	_check(reloaded.restore(bridge_network.snapshot()) and reloaded.tile(Vector2i(110, 33)) == -121, "open timed bridge survives save", failures)


func _test_snapshot_and_validation(failures: Array[String]) -> void:
	var journey := _journey()
	for cycle in 200:
		journey.advance(450)
	var before := journey.snapshot()
	var resumed := _journey()
	_check(resumed.restore(JSON.parse_string(JSON.stringify(before))), "restores JSON-decoded snapshot", failures)
	_check(resumed.snapshot() == before, "round trip preserves partial state", failures)
	var legacy := {"version": 1, "position": [33.0, 62.0], "heading": 6.0, "distance_ticks": 0.0, "phase": 0.0, "blocked": true}
	_check(resumed.restore(legacy) and not resumed.blocked and resumed.position == Vector2i(33, 62), "old trial saves resume on ordinary track", failures)
	var stable := resumed.snapshot()
	var empty_cell := Vector2i(-1, -1)
	for x in RailNetwork.WIDTH:
		if resumed.network.tile(Vector2i(x, 36)) == 0:
			empty_cell = Vector2i(x, 36)
			break
	for invalid in [
		{"version": 2, "position": [empty_cell.x, empty_cell.y], "heading": 6, "distance_ticks": 0, "phase": 0, "blocked": false, "stop_reason": ""},
		{"version": 2, "position": [12, 62], "heading": 5, "distance_ticks": 0, "phase": 0, "blocked": false, "stop_reason": ""},
		{"version": 2, "position": [12, 62], "heading": 6, "distance_ticks": 23, "phase": 0, "blocked": false, "stop_reason": ""},
		{"version": 2, "position": [12, 62], "heading": 6, "distance_ticks": 0, "phase": 3, "blocked": false, "stop_reason": ""},
		{"version": 2, "position": [12, 62], "heading": 6, "distance_ticks": 0, "phase": 0, "blocked": true, "stop_reason": ""},
		{"version": 3, "position": [12, 62], "heading": 6, "distance_ticks": 0, "phase": 0, "blocked": false, "stop_reason": ""},
	]:
		_check(not resumed.restore(invalid), "rejects malformed journey state %s" % JSON.stringify(invalid), failures)
		_check(resumed.snapshot() == stable, "invalid restore leaves state unchanged", failures)


func _test_network_snapshot(failures: Array[String]) -> void:
	var network := _network()
	network.toggle_switch(Vector2i(54, 67))
	var saved: Variant = JSON.parse_string(JSON.stringify(network.snapshot()))
	var restored := _network()
	_check(restored.restore(saved) and restored.tile(Vector2i(54, 67)) == 23, "switch positions survive save and load", failures)
	_check(not restored.restore({"version": 1, "switches": {"12,62": 3}}), "non-switch edits are rejected", failures)
	_check(not restored.restore({"version": 1, "switches": {"54,67": 24}}), "switch values outside the pair are rejected", failures)
	_check(restored.tile(Vector2i(54, 67)) == 23, "rejected restore keeps switches", failures)
	restored.reset()
	_check(restored.tile(Vector2i(54, 67)) == 22 and restored.tile(Vector2i(83, 67)) == 67, "reset returns to the CARTE.FIC map, crevasse included", failures)


func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _test_visual_curve(failures: Array[String]) -> void:
	var journey := _journey(_synthetic({Vector2i(11,62): 2, Vector2i(12,62): 6, Vector2i(13,63): 5}))
	journey.advance(450)
	var point := journey.fractional_position()
	_check(point.x <= 12.0 and point.y == 62.0, "curve before the center remains on entry-to-center rail", failures)
	journey.advance(450)
	point = journey.fractional_position()
	_check(is_equal_approx(point.x - 12.0, point.y - 62.0), "curve past the center follows center-to-exit rail", failures)


func _test_path_samples(failures: Array[String]) -> void:
	var cells := {}
	for x in range(6, 13):
		cells[Vector2i(x, 62)] = 2
	cells[Vector2i(12,62)] = 23
	cells[Vector2i(13,63)] = 5
	cells[Vector2i(14,64)] = 5
	var network := _synthetic(cells)
	var journey := _journey(network)
	var tail: Dictionary = journey.sample_behind(4.0)
	_check(tail.ok and tail.position == Vector2(7.5,62) and tail.heading == 6, "initial tail follows connected straight track", failures)
	_check(not journey.sample_behind(20.0).ok, "missing history is explicit", failures)
	_check(not journey.sample_behind(-1.0).ok and not journey.sample_behind(INF).ok, "invalid offset rejected", failures)
	var last := journey.distance_travelled()
	for cycle in 4:
		var old := journey.fractional_position()
		journey.advance(450)
		var arc := journey.distance_travelled()
		_check(arc >= last, "arc coordinate is monotonic across phase and cell commits", failures)
		_check(journey.fractional_position().distance_to(old) <= arc - last + 0.00001, "movement does not teleport across a phase", failures)
		last = arc
	var samples := []
	for offset in [0.0, 0.25, 0.5, 0.75, 1.0, 2.0, 4.0]:
		var sample: Dictionary = journey.sample_behind(offset)
		_check(sample.ok, "curve history supplies wagon offset", failures)
		if sample.ok:
			var point: Vector2 = sample.position
			_check((point.x <= 12.0 and is_equal_approx(point.y,62.0)) or is_equal_approx(point.x-12.0,point.y-62.0), "wagon point lies on actual straight or diagonal rail", failures)
		samples.append(sample)
	network.toggle_switch(Vector2i(12,62))
	var saved := journey.snapshot()
	var restored := _journey(network)
	_check(restored.restore(JSON.parse_string(JSON.stringify(saved))), "history JSON restore succeeds", failures)
	_check(is_equal_approx(restored.distance_travelled(), journey.distance_travelled()), "restore retains arc coordinate", failures)
	var index := 0
	for offset in [0.0, 0.25, 0.5, 0.75, 1.0, 2.0, 4.0]:
		_check(journey.sample_behind(offset) == samples[index], "switch change cannot rewrite traveled route", failures)
		_check(restored.sample_behind(offset) == samples[index], "saved route restores identical wagon samples", failures)
		index += 1
	var bad := saved.duplicate(true)
	bad.path = [[12,62],[99,62]]
	_check(not restored.restore(bad), "disconnected saved history rejected", failures)
	_check(restored.snapshot() == saved, "failed history restore is atomic", failures)


func _test_legacy_route(failures: Array[String]) -> void:
	var network := _synthetic({Vector2i(12,62): 22, Vector2i(11,62): 2, Vector2i(13,62): 2, Vector2i(13,63): 5})
	var journey := _journey(network)
	var legacy := {"version": 2, "position": [12,62], "heading": 4, "distance_ticks": 0, "phase": 2, "blocked": false, "stop_reason": ""}
	_check(journey.restore(legacy), "legacy trailing-switch state migrates", failures)
	# Phase 2, tick 0: the head is 46/69 - 0.5 = 1/6 cell past the center.
	_check(journey.sample_behind(0.15).ok, "known outgoing half remains renderable after migration", failures)
	_check(not journey.sample_behind(0.2).ok, "legacy ambiguous incoming route is not invented", failures)
	var migrated := journey.snapshot()
	var restored := _journey(network)
	_check(restored.restore(migrated) and restored.snapshot() == migrated, "explicit unknown incoming route round trips", failures)
	var old := journey.distance_travelled()
	for cycle in 3:
		journey.advance(450)
	_check(journey.distance_travelled() >= old, "legacy route resumes and records new actual path", failures)


# TIME 0x26fb on the real map and on synthetic maps for the loop quirks.
func _test_station_lookup(world, failures: Array[String]) -> void:
	var network := _network()
	network.set_city_anchors(world.city_anchors())
	_check(network.station_lookup(Vector2i(131, 68)) == 1, "(131, 68) finds BHOPAL through the 71 tile at (132, 67)", failures)
	_check(network.station_lookup(Vector2i(51, 47)) == 40, "(51, 47) is forced to city record 40", failures)
	_check(network.station_lookup(Vector2i(23, 67)) == -2 and network.station_lookup(Vector2i(148, 60)) == -5, "fixed story stations return -2..-5", failures)
	_check(network.tile(Vector2i(22, 67)) != -122, "story-station map write is not applied", failures)
	_check(network.station_lookup(Vector2i(138, 71)) == -1, "(138, 71) is a station without city", failures)
	var reached := {}
	var with_city := 0
	var stations := 0
	for x in RailNetwork.WIDTH:
		for y in RailNetwork.HEIGHT:
			var code := network.tile(Vector2i(x, y))
			if code < 34 or code > 37:
				continue
			stations += 1
			var result := network.station_lookup(Vector2i(x, y))
			if result >= 0:
				with_city += 1
				reached[result] = true
	_check(stations == 75 and with_city == 46 and reached.size() == 45, "75 station tiles, 46 lead to 45 distinct cities", failures)
	_check(not reached.has(45), "no station reaches record 45 (Tribe of Nomads)", failures)
	# Bound y + dy < 72: a city tile on row 72 is never seen.
	var edge := _synthetic({Vector2i(10, 72): 76, Vector2i(10, 71): 34})
	edge.set_city_anchors([Vector2i(10, 72)])
	_check(edge.station_lookup(Vector2i(10, 71)) == -1, "row 72 is outside the TIME search", failures)
	# Offsets shift the loop counters: after 71 at (-1,-1) -> dx=1, dy=0; a failed
	# record search continues at dy=1 and then leaves the outer loop.
	var quirk := _synthetic({Vector2i(19, 19): 71, Vector2i(20, 20): 34, Vector2i(19, 21): 76, Vector2i(21, 21): 76})
	quirk.set_city_anchors([Vector2i(19, 21), Vector2i(21, 21)])
	_check(quirk.station_lookup(Vector2i(20, 20)) == 1, "shifted counters skip (19, 21) and reach (21, 21)", failures)


func _test_station_departure(world, failures: Array[String]) -> void:
	var network := _network()
	network.set_city_anchors(world.city_anchors())
	var journey := _journey(network)
	network.repair(CREVASSE)
	_drive(journey, 20000)
	_check(journey.at_station() and journey.station_result() == 1, "first route arrives at BHOPAL once the crevasse is bridged", failures)
	var stopped_head := journey.fractional_position()
	var saved := journey.snapshot()
	var restored := _journey(network)
	_check(restored.restore(saved) and restored.station_result() == 1, "a save taken in the city restores the arrival", failures)
	_check(journey.depart_from_station(), "departure is accepted at a station", failures)
	_check(journey.heading == 4 and not journey.blocked and journey.stop_reason.is_empty(), "heading 6 reverses to 4 and the stop clears", failures)
	_check(journey.fractional_position().is_equal_approx(stopped_head), "the locomotive stays at the station port", failures)
	_check(journey.sample_behind(1.0).ok and not journey.sample_behind(1.1).ok, "one hidden cell of history behind the locomotive", failures)
	_check(not journey.depart_from_station(), "departure is refused away from a station", failures)
	var after := journey.snapshot()
	var restored_after := _journey(network)
	_check(restored_after.restore(after) and restored_after.snapshot() == after, "post-departure state round-trips", failures)
	var visited := _drive(journey, 400)
	# (130, 68) is switch 21 (diverging): heading 4 turns to 7 (TIME 0x168c rule for base 20).
	_check(visited.size() > 3 and visited[1] == Vector2i(129, 67) and journey.sample_behind(3.0).ok, "the train leaves by the switch branch and wagons gain history", failures)
