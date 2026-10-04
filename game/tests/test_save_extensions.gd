extends SceneTree
# requires-native-renderer
# Source: native AudioStreamWAV playback; Dummy mixer leaks measured in cadence review.
# MIT. The extension protocol is authored JSON, not original Amiga save bytes.
const Saves = preload("res://scripts/session_saves.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if not value: failures.append(label)

func run() -> void:
	var app=preload("res://scripts/main.gd").new()
	app.save_path_override=ProjectSettings.globalize_path("res://../.cache/extensions-default.json")
	app.size=Vector2(1280,800)
	root.add_child(app)
	app.set_process(false)
	await process_frame
	await process_frame
	var saved: Dictionary=Saves.snapshot(app)
	check(saved.has("campaign") and saved.has("world") and saved.has("works") and saved.has("world_ui"),"snapshot retains campaign/world/works/UI extensions")
	if saved.has("campaign"):
		_test_campaign(app)
		_test_works(app)
		_test_mine(app)
		_test_world(app)
		_test_manual(app)
		_test_capability(app)
		_test_atomic(app)
		_test_legacy_roamers(app)
		_test_legacy(app)
	app.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: campaign/world/works/manual extensions, atomic rejection, UI pending restore, legacy reset")
	quit(0 if failures.is_empty() else 1)

func _test_campaign(app) -> void:
	app.campaign.state.urga_key=true
	app.campaign.state.pending={"scene":"urga","messages":[7,8],"reverse":false}
	app.campaign.page=1
	var lines: Array[String] = ["CONTINUE THE EXPEDITION"]
	app.campaign.screen.present("urga",lines)
	var snapshot: Dictionary=Saves.snapshot(app)
	app.campaign.reset()
	check_restore(app,snapshot,"campaign extension restored")
	check(app.campaign.state.urga_key and app.campaign.page==1 and app.campaign.screen.visible,"campaign gate/page/native presentation restored")
	app.campaign.reset()

func _test_works(app) -> void:
	# Source fixture mirrors test_works_commit: accepted work debits rails before close.
	app.works_dialog.inform(16)
	app.works_dialog.countdown=5
	app._world_session.text_accumulator=app.session.seconds_per_cycle/96.0
	var snapshot: Dictionary=Saves.snapshot(app)
	app.works_dialog.hide()
	app._world_session.text_accumulator=0
	check_restore(app,snapshot,"works extension restores")
	check(app.works_dialog.visible and app.works_dialog.countdown==5,"pending text/countdown restored")
	check(is_equal_approx(app._world_session.text_accumulator,app.session.seconds_per_cycle/96.0),"fractional text scheduler resumes")
	app.works_dialog.hide()

func _test_mine(app) -> void:
	app.calendar.day=3
	check(app.world.tick_mines(3),"source day3 creates actual mine fixture")
	var cell: Vector2i=app.world.mines.mine_cell(app.world.mines.records[0])
	var report: Dictionary=app.world.ask_mine(cell)
	app._world_session.mine_screen.open_mine(report)
	for accepted in [false,true]:
		if accepted:
			app.world.answer_mine(true)
			app._world_session.mine_screen.show_mine()
		var snapshot: Dictionary=Saves.snapshot(app)
		app._world_session.mine_screen.hide()
		check_restore(app,snapshot,"mine question/accepted plaque resumes")
		check(app._world_session.mine_screen.visible and app._world_session.mine_screen.question != accepted,"mine question matches deferred prospect state")
	check(app.world.advance_mine() and app.world.advance_mine() and app.world.close_mine(),"restored accepted mine extracts then closes once")
	check(not app.world.close_mine(),"restored prospect cannot repeat")
	app._world_session.mine_screen.hide()

func _test_world(app) -> void:
	app.wagons.wagons[4][1]=1
	app.engine.lignite=5000
	app.world.visit_city(8)
	app._world_session.workshop.open(app.journey.position)
	app._world_session.workshop.action=52
	app._world_session.workshop.choose_wagon(4)
	var snapshot: Dictionary=Saves.snapshot(app)
	app.world.visited_cities.clear()
	app._world_session.workshop.hide()
	check_restore(app,snapshot,"world workshop extension restores")
	check(app.world.visited_cities==[8] and app._world_session.workshop.visible and app._world_session.workshop.confirmation,"visited station and interrupted repair confirmation restored")
	check(app._world_session.workshop.management==app.world.management,"workshop rebound to restored world management")
	app._world_session.workshop.confirm(false)
	app._world_session.workshop.hide()

func _test_manual(app) -> void:
	var slot: int=app.encounters.enemies.spawn(0,app.encounters.rng)
	app.encounters.pending=slot
	app.encounters.resume_pending()
	var manual=app.encounters.manual
	manual.deploy(0,6,3)
	for tick in 7: manual.step()
	var snapshot: Dictionary=Saves.snapshot(app)
	app.encounters.reset()
	check_restore(app,snapshot,"manual combat extension restores")
	check(app.encounters.manual_scene.visible and app.encounters.manual.ticks==manual.ticks and app.session.paused,"manual actor/tick state reopens actual combat scene")
	if app.encounters.manual != null:
		_test_manual_recovery(app)
	app.encounters.reset()

func _test_manual_recovery(app) -> void:
	var scene=app.encounters.manual_scene
	scene.handle_key(_key(KEY_P))
	check(scene.paused,"P pauses active battle")
	var snapshot: Dictionary=Saves.snapshot(app)
	var battle: Dictionary=app.encounters.manual.snapshot()
	app.encounters.reset()
	check_restore(app,snapshot,"paused battle restores")
	if app.encounters.manual == null:return
	scene=app.encounters.manual_scene
	check(scene.paused,"load preserves battle P pause")
	scene._physics_process(app.encounters.manual.STEP_SECONDS*2)
	check(app.encounters.manual.snapshot()==battle,"paused loaded battle cannot tick")
	scene.handle_key(_key(KEY_P))
	check(not scene.paused,"P resumes loaded battle")
	var before: Dictionary=app.encounters.manual.snapshot()
	scene.handle_key(_key(KEY_F6))
	check(not scene.visible,"F6 opens options above pending battle")
	app._open_panel("room")
	check(scene.visible,"room return reopens pending battle")
	check(app.encounters.manual.snapshot()==before,"options return keeps same actors and ticks")

func _key(code: int) -> InputEventKey:
	var event=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	return event

func _test_capability(app) -> void:
	var base: Dictionary=Saves._stage_base(app,Saves.snapshot(app))
	check(base.ok,"campaign staged base accepts saved journey")
	if not base.ok:return
	check(base.network.campaign_entry_enabled==app.network.campaign_entry_enabled,"staged network retains campaign capability")
	check(base.network._city_anchors==app.world_data.city_anchors(),"staged network retains source city anchors")
	for cell in app.network.STORY_CELLS:
		check(base.network.entry_boundary(cell)==app.network.entry_boundary(cell),"staged story entry has live boundary semantics")

func _test_atomic(app) -> void:
	var before: Dictionary=Saves.snapshot(app)
	var cases: Array=[]
	var bad=before.duplicate(true);bad.campaign.page=-1;cases.append(bad)
	bad=before.duplicate(true);bad.world.pending_mine=999;cases.append(bad)
	bad=before.duplicate(true);bad.works.countdown=128;cases.append(bad)
	bad=before.duplicate(true);bad.world_ui.workshop.selected=999;cases.append(bad)
	bad=before.duplicate(true);bad.world_ui.text_accumulator=app.session.seconds_per_cycle;cases.append(bad)
	bad=before.duplicate(true);bad.world_ui.workshop.confirmation=true;bad.world_ui.workshop.action=50;cases.append(bad)
	bad=before.duplicate(true);bad.calendar.minute=0.5;cases.append(bad)
	bad=before.duplicate(true);bad.calendar.factor="fast";cases.append(bad)
	bad=before.duplicate(true);bad.world.last_mine_day=6;bad.calendar.day=3;cases.append(bad)
	for value in cases:
		value.session.engine.lignite=123
		value.journey.distance=999
		check(not Saves._restore_parsed(app,value).ok,"malformed extension rejected")
		check(Saves.snapshot(app)==before,"rejected extension leaves complete live state untouched")

func _test_legacy(app) -> void:
	var value: Dictionary=Saves.snapshot(app)
	value.version=7
	for key in ["campaign","world","works","world_ui"]: value.erase(key)
	app.campaign.state.urga_key=true
	app.world.visit_city(22)
	check(Saves._restore_parsed(app,value).ok,"legacy save accepted")
	check(not app.campaign.state.urga_key and app.world.visited_cities.is_empty(),"legacy save resets newer state instead of leaking current campaign/world")

func check_restore(app, snapshot: Dictionary, label: String) -> void:
	var result: Dictionary = Saves._restore_parsed(app,JSON.parse_string(JSON.stringify(snapshot)))
	check(result.ok,label + ": " + str(result.get("notice")))


func _test_legacy_roamers(app) -> void:
	# Authored fixture seed fixes migration identity; this is not original history.
	app.encounters.rng.seed = 2026
	var legacy: Dictionary = Saves.snapshot(app)
	legacy.version = 8
	for key in ["roamers","launcher","audio","trade_rng"]: legacy.erase(key)
	var rng := RandomNumberGenerator.new()
	rng.seed = app.encounters.rng.seed
	rng.state = app.encounters.rng.state
	var expected = preload("res://scripts/world_roamers.gd").new()
	expected.initialize(rng,preload("res://scripts/campaign_fauna.gd").new())
	app.roamers.pending = "nomad_trade"
	app.roamers.herds[0][0] += 5
	var commerce_seed: int = app._trade_rng.seed
	var commerce_state: int = app._trade_rng.state
	check_restore(app,legacy,"legacy8 missing populations restore")
	check(app.roamers.snapshot() == expected.snapshot(),"legacy migration uses fresh source baseline rather than live pending transaction")
	check(not app._world_session.roamer_screen.visible and app.roamers.pending.is_empty(),"legacy migration cannot reopen unsaved nomad/hunt encounter")
	check(app._trade_rng.seed == commerce_seed and app._trade_rng.state == commerce_state,"migration never advances commerce RNG")
	check(app.encounters.rng.seed == int(legacy.encounters.seed) and app.encounters.rng.state == int(legacy.encounters.state),"migration never advances saved enemy RNG")
	app.roamers.pending = "nomad_trade"
	check_restore(app,legacy,"repeat legacy8 population restore")
	check(app.roamers.snapshot() == expected.snapshot(),"same legacy save recreates identical populations despite changed live state")
	legacy.erase("encounters")
	check_restore(app,legacy,"pre-encounter legacy save restores deterministic baseline")
	var baseline: Dictionary = app.roamers.snapshot()
	app.roamers.pending = "nomad_trade"
	check_restore(app,legacy,"repeat pre-encounter legacy save")
	check(app.roamers.snapshot() == baseline,"pre-encounter baseline derives only from persisted save identity")
