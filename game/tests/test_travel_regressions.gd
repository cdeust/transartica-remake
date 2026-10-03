extends SceneTree
# requires-native-renderer
# MIT. Owner3Oct: actual Main, pointer/key inputs, native frames, source routes.
const Journey = preload("res://scripts/train_journey.gd")
const Rails = preload("res://scripts/rail_network.gd")
var failures: Array[String] = []
var app
var journey_script = Journey
var captures := "res://../tasks/validation/travel-play-20261003/"

func _initialize() -> void:
	OS.low_processor_usage_mode = false
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	root.size = Vector2i(1280,800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(captures))
	app = load("res://scripts/main.gd").new()
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/travel-play-%d.json" % OS.get_process_id())
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	app.set_process(false)
	await process_frame
	await process_frame
	app._restart_engine()
	app._open_panel("map")
	await process_frame
	await process_frame
	var panel = app._boudoir_session.panel
	await _click(panel.screen_rect(panel.MAP_COMMANDS[5]).get_center())
	check(app.engine.brake and panel.driving_states().brake == "ON","pointer brake applies and exposes ON")
	await _capture("brake-on.png")
	await _click(panel.screen_rect(panel.MAP_COMMANDS[5]).get_center())
	check(not app.engine.brake and panel.driving_states().brake == "OFF","pointer brake releases and exposes OFF")
	await _capture("brake-off.png")
	await _click(panel.screen_rect(panel.MAP_COMMANDS[3]).get_center())
	check(app.journey.reverse and panel.driving_states().direction == "REV","pointer reverser exposes backing")
	await _capture("reverse.png")
	await _click(panel.screen_rect(panel.MAP_COMMANDS[3]).get_center())
	check(not app.journey.reverse,"pointer reverser returns forward")
	await _switch_near_city()
	await _station_trip(false)
	await _station_trip(true)
	await _nomad_trip()
	_test_backing_history()
	_test_live_switch_after_reversal()
	app.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: native pointer brake/reverser/switch, station play forward/backward, camera and live reverse geometry")
	quit(0 if failures.is_empty() else 1)

func _switch_near_city() -> void:
	var view = app.world_view
	view.fit_world()
	await process_frame
	var tested := false
	for x in Rails.WIDTH:
		for y in Rails.HEIGHT:
			var cell := Vector2i(x,y)
			if not app.network.is_switch(cell): continue
			var at: Vector2 = view._world_to_screen(Vector2(cell)+Vector2.ONE*0.5)
			if view._city_at(at) < 0: continue
			var before: int = app.network.tile(cell)
			await _click(view.global_position+at)
			check(app.network.tile(cell) != before,"actual switch click wins over neighbouring city hit area at %s" % cell)
			tested = true
			break
		if tested: break
	check(tested,"supplied map provides switch/city pointer collision")

func _station_trip(backing: bool) -> void:
	# Fixture starts on the supplied BHOPAL approach; after setup, all controls
	# and scene responses go through the actual viewport input and Main cadence.
	app._trade_rng.seed = 1
	app._restart_engine()
	app.journey.position = Vector2i(126,68)
	app.journey.heading = 4 if backing else 6
	app.engine.heat = 2500 # Same rolling state as test_playable_trip, not a rule.
	app.engine.pressure_reserve = 15000
	app.engine.regulator = 300
	app.engine.speed = 300
	app.engine.lignite_rate = 1
	app._open_panel("map")
	await process_frame
	await process_frame
	app.world_view.fit_complete_consist()
	if backing:
		await _click(app._boudoir_session.panel.screen_rect(app._boudoir_session.panel.MAP_COMMANDS[3]).get_center())
	await _capture("approach-%s.png" % ("reverse" if backing else "forward"))
	var cycles := 0
	while not app.journey.blocked and cycles < 80:
		if app.campaign.blocks_simulation() or app._world_session.blocks_simulation():
			await _key(KEY_ESCAPE)
			await _key(KEY_ENTER)
			if app.engine.brake: await _key(KEY_B)
		else:
			app._process(app.session.seconds_per_cycle)
			cycles += 1
			app.world_view._process(app.session.seconds_per_cycle)
			await process_frame
	check(app.journey.at_station() and app.journey.station_result() == 1,"played route reaches BHOPAL backing=%s" % backing)
	check(app._city_panel.visible and app._city_panel.city == 1,"played arrival opens correct city backing=%s" % backing)
	check(app.world_view._visual_position.is_equal_approx(app.journey.fractional_position()),"arrival finishes rendered approach before pausing backing=%s" % backing)
	await _capture("city-%s.png" % ("reverse" if backing else "forward"))
	# Inspect the map without departing, then return to the same city via Escape.
	await _click(app._boudoir_session.panel.screen_rect(app._boudoir_session.panel.MAP_COMMANDS[4]).get_center())
	await _capture("stopped-%s.png" % ("reverse" if backing else "forward"))
	var nose: Vector2 = app.world_view._world_to_screen(app.world_view._visual_position+Vector2.ONE*0.5)
	check(Rect2(Vector2.ZERO,app.world_view.size).has_point(nose),"stopped locomotive remains in visible map backing=%s" % backing)
	check(not app.world_view.train_renderer.poses(app.world_view,app.journey,app.world_view.consist,0.0).is_empty(),"station approach still draws locomotive backing=%s" % backing)
	await _key(KEY_ESCAPE)
	await _key(KEY_ENTER)
	check(not app._city_panel.visible and not app.journey.blocked,"actual city EXIT departs backing=%s" % backing)
	if app.engine.brake: await _key(KEY_B)
	# Source acceleration5/cycle:36 cycles supplies more than one tile's69
	# distance ticks after the station resets speed to zero.
	for cycle in 36:
		app._process(app.session.seconds_per_cycle)
		app.world_view._process(app.session.seconds_per_cycle)
		await process_frame
	await _click(app._boudoir_session.panel.screen_rect(app._boudoir_session.panel.MAP_COMMANDS[4]).get_center())
	await _capture("departure-%s.png" % ("reverse" if backing else "forward"))
	check(app.journey.position != Vector2i(130,68),"native departure continues along track backing=%s" % backing)
	check(app.world_view._visual_position.is_equal_approx(app.journey.fractional_position()),"map reopening shows current departing train backing=%s" % backing)
	check(not app.world_view.train_renderer.poses(app.world_view,app.journey,app.world_view.consist,0.0).is_empty(),"departing locomotive is actually rendered backing=%s" % backing)

func _network(cells: Dictionary):
	var bytes := PackedByteArray()
	bytes.resize(Rails.WIDTH*Rails.HEIGHT)
	for cell in cells: bytes[cell.x*Rails.HEIGHT+cell.y] = cells[cell]
	var network = Rails.new()
	network.load_bytes(bytes)
	return network

func _test_backing_history() -> void:
	var cells := {}
	for x in range(1,30): cells[Vector2i(x,20)] = 2
	cells[Vector2i(6,20)] = 20 # East exits from W or NW: seed history is ambiguous.
	var journey = journey_script.new()
	journey.network = _network(cells)
	journey.position = Vector2i(12,20)
	journey.reverse_direction()
	for cycle in 24: journey.advance(450)
	check(journey.position.x < 6 and journey.fractional_position().x < 6,"backing extends beyond finite initial route history")
	var saved = journey_script.new()
	saved.network = journey.network
	check(saved.restore(journey.snapshot()),"extended backing path remains saveable")
	check(saved.fractional_position().is_equal_approx(journey.fractional_position()),"restored backing train stays on the same rail")
	check(is_equal_approx(saved.distance_travelled(),journey.distance_travelled()),"restored render origin preserves arc coordinate")
	saved.advance(450)
	journey.advance(450)
	check(saved.fractional_position().is_equal_approx(journey.fractional_position()),"restored backing journey continues without jumping")
	if journey.snapshot().version >= 5:
		var malformed: Dictionary = journey.snapshot()
		malformed.erase("render_origin")
		var before: Dictionary = saved.snapshot()
		check(not saved.restore(malformed) and saved.snapshot() == before,"missing render origin rejects save atomically")

func _test_live_switch_after_reversal() -> void:
	var cells := {}
	for x in range(1,30): cells[Vector2i(x,20)] = 2
	cells[Vector2i(12,20)] = 22
	cells[Vector2i(13,21)] = 5
	var journey = journey_script.new()
	journey.network = _network(cells)
	journey.position = Vector2i(12,20)
	journey.reverse_direction()
	journey.reverse_direction()
	journey.network.toggle_switch(Vector2i(12,20))
	for cycle in 3: journey.advance(450)
	check(journey.heading == 3,"live switch turns logical train after reverser round trip")
	var point: Vector2 = journey.fractional_position()
	check(is_equal_approx(point.x-12,point.y-20),"live switch also turns displayed train after reverser round trip")

func _click(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func _key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func _capture(filename: String) -> void:
	app._boudoir_session.refresh()
	app.world_view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(captures+filename))


func _nomad_trip() -> void:
	# Source TIME258a..25ee and YODA811: NOMADS is mobile city45,
	# not a fixed station. Prepare its source spawn, then play the encounter.
	for backing in [false,true]:
		app._trade_rng.seed = 1
		app._restart_engine()
		app.journey.position = app.roamers.nomad_cell()
		app._open_panel("map")
		await process_frame
		if backing: await _click(app._boudoir_session.panel.screen_rect(app._boudoir_session.panel.MAP_COMMANDS[3]).get_center())
		app._process(app.session.seconds_per_cycle)
		await process_frame
		check(app._world_session.roamer_screen.visible,"native nomad encounter backing=%s" % backing)
		await _capture("nomad-question-%s.png" % backing)
		await _key(KEY_ENTER)
		check(app._city_panel.visible and app._city_panel.city == 45,"native NOMADS trade city backing=%s" % backing)
		await _capture("nomad-city-%s.png" % backing)
		await _key(KEY_ENTER)
		check(not app._city_panel.visible and app.roamers.pending.is_empty(),"native NOMADS EXIT backing=%s" % backing)
