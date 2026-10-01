extends SceneTree
# requires-native-renderer
# MIT. Isolated nomad-position fixture verifies actual production encounter/save UI.
# This is a regression test, not earned campaign completion evidence.
const Saves = preload("res://scripts/session_saves.gd")
var failures := 0
var app
func _initialize() -> void:
	OS.low_processor_usage_mode = false
	_run.call_deferred()
func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await process_frame
	await process_frame

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(not image.is_empty(), "native roamer screen capture")
	var path := ProjectSettings.globalize_path("res://../tasks/validation/" + name + "-20261001.png")
	check(image.save_png(path) == OK,"preserve native roamer capture")
	var scene = app._world_session.roamer_screen # source: production nomad/herd presentation fixture.
	var bounds: Rect2 = scene.scene_bounds(Rect2(0,39,320,110))
	check(is_equal_approx(bounds.size.aspect(),scene._scene.get_size().aspect()),"roamer artwork retains authored aspect")
func _run() -> void:
	app = load("res://scripts/main.gd").new()
	app.size = Vector2(1280,800)
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/restore-city-auto.SAV")
	root.add_child(app)
	app.set_process(false)
	await process_frame
	app._restart_engine()
	app.roamers.nomad = [app.journey.position.x,app.journey.position.y,0,6,0]
	check(app._world_session.encounter_roamers(app.journey.position,4),"actual dynamic presence opens nomad question")
	check(app._world_session.roamer_screen.visible and app._world_session.roamer_screen.question,"nomad question visible")
	await capture("nomad-question-native")
	await key(KEY_ENTER)
	check(app._city_panel.visible and app.roamers.pending == "nomad_trade","viewport Return accepts nomads and opens original trade city45")
	app.trade.stock[45-app.trade.FIRST_TRADING_CITY][3] = 3 # Source-valid stock fixture after purchases.
	var stock: Array = app.trade.snapshot().stock
	var rng_seed: int = app._trade_rng.seed
	var rng_state: int = app._trade_rng.state
	var pending: Dictionary = app.roamers.snapshot()
	var path := ProjectSettings.globalize_path("res://../.cache/nomad-interrupted.SAV")
	check(Saves.save(app,path).ok,"save actual nomad trade UI")
	app._city_panel.hide()
	app.trade.visit(45,app._trade_rng)
	app.roamers.close()
	check(Saves.restore(app,path).ok,"restore actual nomad trade UI")
	check(app.trade.snapshot().stock == stock,"saved nomad stock3 is not rerolled by presentation")
	check(app._trade_rng.seed == rng_seed and app._trade_rng.state == rng_state,"saved commerce RNG exact")
	check(app._city_panel.visible and app.roamers.snapshot() == pending,"dynamic trade pending state and UI restored")
	var heading: int = app.journey.heading
	app.depart_from_city()
	check(not app._city_panel.visible and app.roamers.pending == "" and app.journey.heading != heading,"nomad departure reverses without a static station")
	# A separate valid cargo fixture tests interrupted hunting, not route economics.
	app.wagons.wagons[5] = [7,0,0,0]
	app.roamers.herds[0][0] = app.journey.position.x-40
	app.roamers.herds[0][1] = app.journey.position.y
	check(app._world_session.encounter_roamers(app.journey.position,2),"presence opens herd question")
	await capture("mammoth-question-native")
	await key(KEY_ENTER)
	check(app.roamers.pending == "hunt_commissioned","viewport Return commissions hunt")
	await key(KEY_ENTER)
	check(app.roamers.pending == "hunt_result" and app.wagons.wagons[5][3] > 0,"viewport Return runs source capture")
	app._world_session.advance_text(app.session.seconds_per_cycle/48*0.3)
	var accumulator: float = app._world_session.text_accumulator
	var hunt_cargo: Array = app.wagons.snapshot()
	var hunt_saved: Dictionary = app.roamers.snapshot()
	check(Saves.save(app,path).ok,"save interrupted hunt cadence")
	app.roamers.close()
	app._world_session.roamer_screen.hide()
	app._world_session.text_accumulator = 0.0
	check(Saves.restore(app,path).ok,"restore interrupted hunt")
	check(app._world_session.roamer_screen.visible and app.roamers.snapshot() == hunt_saved and app.wagons.snapshot() == hunt_cargo,"hunt report/cargo restores without reward duplication")
	check(is_equal_approx(app._world_session.text_accumulator, accumulator),"hunt fractional source text cadence persists")
	await key(KEY_ENTER)
	check(app.roamers.pending == "" and app.wagons.snapshot() == hunt_cargo,"viewport report close does not duplicate catch")
	app.queue_free()
	await process_frame
	print("PASS: actual nomad/hunt native art and save restoration" if failures == 0 else "FAIL nomad city restore %d" % failures)
	quit(failures)
