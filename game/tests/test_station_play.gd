extends "res://tests/test_travel_regressions.gd"
# requires-native-renderer
# MIT. Every supplied station, actual Main cadence and viewport input.
const Glyphs = preload("res://scripts/rail_glyphs.gd")
const Works = preload("res://scripts/track_works.gd")
var shots: Array[Image] = []
var shot_names: Array[String] = []
var rows: Array[Dictionary] = []
var sheet := 0
var region_by_station := {}

func _run() -> void:
	root.size = Vector2i(1280,800)
	captures = "res://../tasks/validation/station-play-20261003/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(captures))
	app = load("res://scripts/main.gd").new()
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/station-play-%d.json" % OS.get_process_id())
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	app.set_process(false)
	await process_frame
	await process_frame
	var stations: Array[Vector2i] = []
	for x in Rails.WIDTH:
		for y in Rails.HEIGHT:
			if app.world_data.map_code(x,y) in [34,35,36,37]: stations.append(Vector2i(x,y))
	for region in app.campaign.state.data.regions:
		for record in app.campaign.state.data.regions[region]:
			if not int(record[2]) in [34,35,36,37]: continue
			var cell := Vector2i(int(record[0])+(256 if region == "trans" else 0),int(record[1]))
			region_by_station[cell] = region
			if not cell in stations: stations.append(cell)
	for station in stations:
		for backing in [false,true]: await _play_station(station,backing)
	_flush_sheet()
	var result := {"stations":stations.size(),"runs":rows,"failures":failures,
		"scope":"Prepared source-map approaches, native Main/input. Isolated150,41/42 are local fixtures, not a fabricated world route."}
	var file := FileAccess.open(ProjectSettings.globalize_path(captures+"results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	app.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: %d station sites / %d native forward-backward runs, campaign passages/finale and rendered contact sheets" % [stations.size(),rows.size()])
	quit(0 if failures.is_empty() else 1)

func _play_station(station: Vector2i, backing: bool) -> void:
	await _prepare_station(station,backing)
	var label := "%d,%d %s" % [station.x,station.y,"REV" if backing else "FWD"]
	var approach := await _drive_approach(station,label)
	var cycles: int = approach.cycles
	var source_passage: bool = approach.passage
	if source_passage:
		check(not app._city_panel.visible and not app.journey.blocked,label+": source campaign opens passage instead of false arrival")
		await _shot(label+" campaign passage")
		rows.append({"station":[station.x,station.y],"reverse":backing,"cycles":cycles,"arrival":"campaign passage","city":-1,"departed":true})
		print("PLAY "+label+" -> campaign passage")
		return
	check(app.journey.at_station() and app.journey.next_cell() == station,label+": actual cadence reaches correct station")
	var expected: int = app.network.station_lookup(station)
	var vehicle_count: int = app.world_view.train_renderer.poses(app.world_view,app.journey,app.world_view.consist,0.0).size()
	check(vehicle_count > 0,label+": locomotive pose remains available at arrival")
	# Resolve the original manual quiz before the city menu, through real keys.
	while app.campaign.state.pending.get("scene") == "manual_quiz": await _respond()
	var arrival: String = "city%d" % app._city_panel.city if app._city_panel.visible else str(app.campaign.state.pending.get("scene","notice"))
	if expected >= 0: check(app._city_panel.visible and app._city_panel.city == expected,label+": correct city presentation")
	else: check(app.campaign.screen.visible or app.works_dialog.visible,label+": source station notice/event presented")
	await _shot(label+" "+arrival)
	await _leave_station(expected,label)
	var finale: bool = app.campaign.state.ending == "sun" and app._boudoir_session.reception.visible
	if finale: await _shot(label+" finale OPTIONS")
	check(not app.journey.blocked or finale,label+": actual EXIT leaves station or finale reaches OPTIONS")
	rows.append({"station":[station.x,station.y],"reverse":backing,"cycles":cycles,"arrival":arrival,"city":expected,"departed":not app.journey.blocked,"finale":finale,"vehicles":vehicle_count})
	print("PLAY "+label+" -> "+arrival+" EXIT "+str(not app.journey.blocked),true)

func _respond() -> bool:
	if app.campaign.screen.visible:
		var event: Dictionary = app.campaign.state.pending
		if app.campaign.screen.scene == "sun-restored":
			await app.campaign.screen.movie_finished
			await process_frame
		elif event.get("scene") == "manual_quiz":
			var answer: String = app.campaign.state.data.quizzes[event.quiz][event.index].answer
			for character in answer:
				var key := InputEventKey.new()
				key.unicode = character.unicode_at(0)
				key.pressed = true
				root.push_input(key,true)
				await process_frame
			await _key(KEY_ENTER)
		elif app.campaign.screen.entering_code:
			for character in app.campaign.state.DELIVERY_CODE:
				var key := InputEventKey.new()
				key.unicode = character.unicode_at(0)
				key.pressed = true
				root.push_input(key,true)
				await process_frame
			await _key(KEY_ENTER)
		else: await _key(KEY_ENTER)
		return true
	if app._world_session.blocks_simulation():
		await _key(KEY_ESCAPE)
		await _key(KEY_ENTER)
		return true
	if app.works_dialog.visible:
		var button = app.works_dialog._no if app.works_dialog._yes.visible else app.works_dialog._ok
		await _click(button.global_position+button.size*0.5)
		return true
	return false

func _shot(label: String) -> void:
	app._boudoir_session.refresh()
	app.world_view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	pixels.convert(Image.FORMAT_RGB8)
	pixels.resize(640,400,Image.INTERPOLATE_NEAREST)
	shots.append(pixels)
	shot_names.append(label)
	if shots.size() == 10: _flush_sheet()

func _flush_sheet() -> void:
	if shots.is_empty(): return
	var montage := Image.create(1280,2000,false,Image.FORMAT_RGB8)
	for index in shots.size(): montage.blit_rect(shots[index],Rect2i(0,0,640,400),Vector2i(index%2*640,index/2*400))
	montage.save_png(ProjectSettings.globalize_path(captures+"sheet-%02d.png" % sheet))
	var file := FileAccess.open(ProjectSettings.globalize_path(captures+"sheet-%02d.json" % sheet),FileAccess.WRITE)
	file.store_string(JSON.stringify(shot_names,"\t"))
	shots.clear()
	shot_names.clear()
	sheet += 1


func _prepare_station(station: Vector2i,backing: bool) -> void:
	app._trade_rng.seed = 1
	app._restart_engine()
	if region_by_station.has(station):
		# Prepared post-disclosure fixture: use the actual source entry writes,
		# including the neighbouring rails required to approach hidden stations.
		var region: String = region_by_station[station]
		for record in app.campaign.state.data.regions[region]:
			var revealed := Vector2i(int(record[0])+(256 if region == "trans" else 0),int(record[1]))
			app.campaign.state.prepare_entry(revealed,6,app.wagons,app.network)
	var station_port: Vector2 = Glyphs.ports_for_code(app.network.tile(station))[0]
	var heading := 0
	for candidate in Rails.DELTAS:
		if -Vector2(Rails.DELTAS[candidate])*0.5 == station_port: heading = candidate
	var cell: Vector2i = station-Rails.DELTAS[heading]
	if not Works.kind_for(app.network.tile(cell)).is_empty(): app.network.repair(cell)
	app.campaign.state.prepare_entry(cell,heading,app.wagons,app.network)
	var incoming := heading
	var ports := Glyphs.ports_for_code(app.network.tile(cell))
	var found := false
	for candidate in Rails.DELTAS:
		if candidate != 5 and -Vector2(Rails.DELTAS[candidate])*0.5 in ports and app.network.turn(cell,candidate) == heading:
			incoming = candidate
			found = true
			break
	if not found and app.network.is_switch(cell):
		app.network.toggle_switch(cell) # Source switch preparation before native play.
		for candidate in Rails.DELTAS:
			if candidate != 5 and -Vector2(Rails.DELTAS[candidate])*0.5 in ports and app.network.turn(cell,candidate) == heading:
				incoming = candidate
				break
	app.journey.position = cell
	app.journey.heading = 10-heading if backing else incoming
	app.journey.phase = 2 if backing else 0
	app.engine.heat = 2500 # Existing rolling-state fixture, test_playable_trip.
	app.engine.pressure_reserve = 15000
	app.engine.regulator = 300
	app.engine.speed = 300
	app.engine.lignite_rate = 1
	app._open_panel("map")
	await process_frame
	await process_frame
	app.world_view.zoom = 0.6 # Authored review scale, constant throughout each run.
	app.world_view._snap_visual_position(app.journey.fractional_position())
	app.world_view.center_on_train()
	if backing: await _click(app._boudoir_session.panel.screen_rect(app._boudoir_session.panel.MAP_COMMANDS[3]).get_center())


func _drive_approach(station: Vector2i,label: String) -> Dictionary:
	var cycles := 0
	var source_passage := false
	while not app.journey.blocked and cycles < 120:
		if await _respond():
			if app.engine.brake: await _key(KEY_B)
		else:
			# A second native test window can cause the legitimate focus pause.
			# Resume with the player's key; count simulation cycles, not frames.
			if app.session.paused: await _key(KEY_SPACE)
			var before: int = app.engine.cycles
			app._process(app.session.seconds_per_cycle)
			app.world_view._process(app.session.seconds_per_cycle)
			await process_frame
			cycles += app.engine.cycles-before
			check(not app._city_panel.visible or app.journey.at_station(),label+": no city before station boundary")
			if app.journey.position == station and not app.network.tile(station) in [34,35,36,37]:
				# TIME0x1fc8 removes the39,32 terminal while revealing Hima.
				source_passage = true
				break
	return {"cycles":cycles,"passage":source_passage}


func _leave_station(expected: int,label: String) -> void:
	# Actual city inspection temporarily exposes the stopped train on the map.
	if app._city_panel.visible:
		await _click(app._boudoir_session.panel.screen_rect(app._boudoir_session.panel.MAP_COMMANDS[4]).get_center())
		check(app.world_view._visual_position.is_equal_approx(app.journey.fractional_position()),label+": rendered arrival is current")
		_check_locomotive_frame(label)
		await _shot(label+" port")
		await _key(KEY_ESCAPE)
		if app._city_panel.in_transaction(): await _key(KEY_ESCAPE)
		await _key(KEY_ENTER)
	else:
		while app.journey.blocked and await _respond(): pass
		if app.journey.blocked and expected == -1:
			# Source TEXTEK16 is an empty terminal notice. As in the campaign
			# route driver, the player chooses the available YODA reverser.
			await _key(KEY_M)
			check(app.world_view.is_visible_in_tree(),label+": empty terminal can be inspected on the map")
			check(app.world_view._visual_position.is_equal_approx(app.journey.fractional_position()),label+": empty terminal arrival is current")
			_check_locomotive_frame(label)
			await _capture("terminal-port-"+label.replace(" ","-")+".png")
			app._boudoir_session.refresh()
			await _click(app._boudoir_session.panel.screen_rect(app._boudoir_session.panel.MAP_COMMANDS[3]).get_center())


func _check_locomotive_frame(label: String) -> void:
	var view = app.world_view
	var locomotive := {"vehicles":[view.consist.vehicles[0]]}
	var bounds: Rect2 = view.train_renderer.screen_bounds(view,app.journey,locomotive,0.0)
	check(Rect2(Vector2.ZERO,view.size).encloses(bounds),label+": whole locomotive stays inside the rendered viewport")
