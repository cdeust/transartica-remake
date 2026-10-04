extends SceneTree
# requires-native-renderer
# MIT. Prepared Main fixture with source-generated mine; not earned gameplay.
const Saves = preload("res://scripts/session_saves.gd")
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app = preload("res://main.tscn").instantiate()
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/mining-extraction-unused.json")
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.game_audio.set_process(false)
	# Explicit Dummy-mixer model: no native audio playback claim.
	app.game_audio.reset()
	app.game_audio.manifest.clear()
	app.game_audio.music_manifest.clear()
	app._restart_engine()
	if "--before-mining" in OS.get_cmdline_user_args():
		var before = load(ProjectSettings.globalize_path("res://../.cache/mining-extraction-fix-20261004/world_actions_before.gd")).new()
		before.attach(app.journey,app.wagons,app.engine,app.trade,app.world.rng)
		app.world = before
	app.calendar.day = 3
	check(app.world.tick_mines(3),"source creates mine on actual map")
	var cell: Vector2i = app.world.mines.mine_cell(app.world.mines.records[0])
	var record: Array = app.world.mines.records[0]
	app.engine.lignite = 494
	app.engine.anthracite = 0
	app.wagons.wagons.append([5,0,0,24]) # explicit model crew, not native resources.
	var coordinator = app._world_session
	coordinator.mine_screen.open_mine(app.world.ask_mine(cell))
	app.session.paused = true
	if not app.world.has_method("advance_mine"):
		app.world.answer_mine(true)
		app.world.close_mine()
		check(app.engine.lignite + app.engine.anthracite > 494,"before: source mining must credit coal")
		for error in errors: push_error(error)
		app.game_audio.reset()
		app.queue_free()
		await process_frame
		quit(0 if errors.is_empty() else 1)
		return
	roundtrip(app,"question")
	coordinator._answer_mine(true)
	roundtrip(app,"plaque")
	var legacy: Dictionary = JSON.parse_string(JSON.stringify(Saves.snapshot(app)))
	for field in ["mine_phase","mine_resources","mine_quantity","mine_countdown"]: legacy.world.erase(field)
	check(Saves._restore_parsed(app,legacy).ok and app.world.mine_phase=="plaque","legacy accepted save migrates without credit")
	var invalid: Dictionary = JSON.parse_string(JSON.stringify(Saves.snapshot(app)))
	invalid.world.erase("mine_quantity")
	check(not Saves._restore_parsed(app,invalid).ok and app.world.mine_phase=="plaque","partial phase fields rejected atomically")
	check(not app.world.close_mine(),"plaque cannot close before extraction")
	coordinator._close_mine()
	roundtrip(app,"resources")
	check(app.engine.lignite == 494 and app.engine.anthracite == 0,"resources report does not credit")
	var expected: int = (int(record[3])+1)*5 # work24 ->integer24/5+1=5.
	coordinator._close_mine()
	check(app.world.mine_quantity == expected,"production uses source quantity")
	check(app.engine.anthracite == expected if record[2]<0 else app.engine.lignite == 494+expected,"ore selection credits expected fuel")
	check(app.network.tile(cell)==78 and app.world.mine_countdown==60,"credited result keeps open mine")
	coordinator.advance_text(app.session.seconds_per_cycle /48 * 7.5)
	roundtrip(app,"result")
	var coal: int = app.engine.lignite + app.engine.anthracite
	check(not app.world.advance_mine() and app.engine.lignite+app.engine.anthracite==coal,"result cannot credit twice")
	for tick in 60: app.world.mine_text_tick()
	check(app.world.mine_phase=="result" and app.network.tile(cell)==78 and app.calendar.factor==3,"expiry cannot auto-close or normalize fast clock")
	coordinator._close_mine()
	check(app.network.tile(cell)==79 and app.world.pending_mine==-1,"result dismissal closes source mine")
	check(app.engine.lignite+app.engine.anthracite==coal,"close cannot credit again")
	app.game_audio.reset()
	app.queue_free()
	await process_frame
	for error in errors: push_error(error)
	if errors.is_empty(): print("PASS: prepared Main mining phases, JSON restore, single credit and deferred close")
	quit(0 if errors.is_empty() else 1)
func roundtrip(app, phase: String) -> void:
	var saved: Dictionary = JSON.parse_string(JSON.stringify(Saves.snapshot(app)))
	check(Saves._restore_parsed(app,saved).ok,"restore phase "+phase)
	check(app.world.mine_phase==phase and app._world_session.mine_screen.visible,"phase presentation "+phase)
func check(ok: bool, label: String) -> void:
	if not ok: errors.append(label)
