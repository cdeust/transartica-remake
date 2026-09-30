extends SceneTree
# MIT. The extension protocol is authored JSON, not original Amiga save bytes.
const Saves = preload("res://scripts/session_saves.gd")
var failures: Array[String] = []

class ExtendedApp extends "res://scripts/main.gd":
	var campaign = preload("res://scripts/campaign_session.gd").new()
	var world = preload("res://scripts/world_actions.gd").new()
	var _world_session = preload("res://scripts/world_session.gd").new()
	func _ready() -> void:
		super._ready()
		world.attach(journey,wagons,engine,trade,_trade_rng)
		campaign.attach(self)
		_world_session.attach(self)

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if not value: failures.append(label)

func run() -> void:
	var app=ExtendedApp.new()
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
		_test_atomic(app)
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
	check(app.world.close_mine(),"restored accepted mine closes once")
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
	app.encounters.reset()

func _test_atomic(app) -> void:
	var before: Dictionary=Saves.snapshot(app)
	var cases: Array=[]
	var bad=before.duplicate(true);bad.campaign.page=-1;cases.append(bad)
	bad=before.duplicate(true);bad.world.pending_mine=999;cases.append(bad)
	bad=before.duplicate(true);bad.works.countdown=128;cases.append(bad)
	bad=before.duplicate(true);bad.world_ui.workshop.selected=999;cases.append(bad)
	bad=before.duplicate(true);bad.world_ui.text_accumulator=app.session.seconds_per_cycle;cases.append(bad)
	bad=before.duplicate(true);bad.world_ui.workshop.confirmation=true;bad.world_ui.workshop.action=50;cases.append(bad)
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
