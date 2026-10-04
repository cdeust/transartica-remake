extends SceneTree
# MIT. Prepared Main integration, actual earned10361 geometry. Not native play.
# Source: Campaign.before_entry ordering, TIME spy/hidden dispatch, fauna pages.
const CurrentSaves = preload("res://scripts/session_saves.gd")
var Saves
var Dispatch
const Stop = preload("res://scripts/reverse_contact_stop.gd")
const FIXTURE := "res://../reference-private/validation/reverse-hidden-partial-earned.json"
var errors: Array[String] = []
var app
var path := ""
func check(ok: bool, label: String) -> void:
	if not ok: errors.append(label)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	Saves = load("res://../.cache/reverse-hidden-contact-fix-20261004/before-saves.gd") if "--before-history-guard" in OS.get_cmdline_user_args() else CurrentSaves
	Dispatch = load("res://../.cache/reverse-hidden-contact-fix-20261004/before-dispatch.gd" if "--before-special" in OS.get_cmdline_user_args() else "res://scripts/journey_session.gd")
	app = preload("res://scripts/main.gd").new()
	path = ProjectSettings.globalize_path("res://../.cache/reverse-hidden-contact-fix-20261004/modal-%d.SAV" % OS.get_process_id())
	app.save_path_override = path
	# Dummy audio exclusion only: preserve the real game/save/UI dispatch.
	app.game_audio.effects_enabled = false
	app.game_audio.music_enabled = false
	app.size = Vector2(1280,800)
	root.add_child(app)
	app.set_process(false)
	await process_frame
	for scenario in ["spy_yes","spy_no","wolf"]:
		var scene: String = "wolf" if scenario=="wolf" else "spy_pickup"
		var restored: Dictionary = Saves.restore(app,ProjectSettings.globalize_path(FIXTURE))
		check(restored.ok,"unchanged raw earned10361 restores through full production pipeline")
		if not restored.ok: break
		check(app.world_view.train_renderer.poses(app.world_view,app.journey,app.world_view.consist,0.0).size()==1,"raw10361 has one complete rendered locomotive")
		var stable: Dictionary = Saves.snapshot(app)
		var short: Dictionary = stable.duplicate(true)
		short.journey.render_cursor = 0.01 # Prepared invalid history below its rigid chord.
		check(not Saves._restore_parsed(app,short).ok,"actual renderer refuses incomplete locomotive history")
		check(Saves.snapshot(app)==stable,"failed rendered-history restore remains atomic")
		app.game_audio.effects_enabled = false
		app.game_audio.music_enabled = false
		var cell := Vector2i(44,30)
		var revealed_code := 0
		for record in app.campaign.state.data.regions.hima:
			if Vector2i(int(record[0]),int(record[1]))==cell: revealed_code=int(record[2])
		check(app.network.tile(cell)==-115,"prepared modal begins at still-hidden source cell")
		if scene=="spy_pickup":
			# Prepared recruited slot, then actual source send/travel state machine.
			app.trade.spy_slots[0] = 1
			app.campaign.state.spies[0].fill(0)
			var spy: int = app.campaign.state.send_spy(cell,app.journey.position,app.wagons,app.trade)
			check(spy==0,"prepared spy dispatched by source command")
			while app.campaign.state.spies[0][0]==2:
				app.campaign.state.advance_spies(app.network,app.trade,app.stoup)
			check(app.campaign.state.posted_at(cell)==0,"spy genuinely reaches physical source cell")
		else:
			# Prepared legal roaming wolf position; before_fauna and modal are real.
			app.campaign.state.fauna.initialized = true
			app.campaign.state.fauna.cell = cell
			app.campaign.state.fauna.heading = 6
			app.campaign.state.fauna.phase = 0
			app.campaign.state.fauna.counter = 0
			app.campaign.state.fauna.frozen = false
		Stop.advance(app.world_view,app.journey,300)
		check(app.journey.blocked and app.journey.boundary_cell()==cell,"actual contact guard prepares physical special stop")
		var stopped_cell: Vector2i = app.journey.position
		var stopped_phase: int = app.journey.phase
		var stopped_ticks: int = app.journey.distance_ticks
		Dispatch._handle_boundary(app,false)
		check(app.campaign.state.pending.get("scene")==scene and app.campaign.screen.visible,"real pre-entry opens legitimate "+scene+" modal")
		check(app.network.tile(cell)==(-115 if scene=="spy_pickup" else revealed_code),"source spy precedes reveal; wolf follows reveal")
		check(app.journey.stop_reason=="special site","modal preserves suspended physical handler")
		var direct = load("res://../.cache/reverse-hidden-contact-fix-20261004/before-journey.gd" if "--before-special" in OS.get_cmdline_user_args() else "res://scripts/train_journey.gd").new()
		direct.network = app.network
		check(direct.restore(app.journey.snapshot()),"physical special modal journey validates")
		var saved: Dictionary = Saves.save(app,path)
		check(saved.ok,"production session saves open "+scene)
		var loaded: Dictionary = Saves.restore(app,path)
		check(loaded.ok,"production session restores open "+scene)
		check(app.campaign.screen.visible and app.session.paused and app.journey.boundary_cell()==cell,"restore retains modal and physical boundary")
		if not loaded.ok: break
		var pending: Dictionary = app.campaign.snapshot()
		Dispatch.advance(app)
		check(app.campaign.snapshot()==pending and app.journey.position==stopped_cell and app.journey.phase==stopped_phase and app.journey.distance_ticks==stopped_ticks,"open modal retains ownership without repeating preparation")
		if scene=="spy_pickup":
			app.campaign._answer(scenario=="spy_yes")
			if scenario=="spy_no":
				check(app.campaign.state.posted_at(cell)==0,"NO retains posted spy")
				check(app.journey.physical_spy_handled,"NO retains same-entry continuation")
				check(Saves.save(app,path).ok and Saves.restore(app,path).ok,"NO continuation survives save/reload after dismissal")
		else:
			while app.campaign.screen.visible:
				app.campaign._continue()
		check(app.campaign.state.pending.is_empty() and not app.session.paused,"real modal dismissal resumes session")
		Dispatch.advance(app)
		check(not app.journey.blocked and app.journey.physical_obstacle==Vector2i(-1,-1),"dismissed modal retries and releases same physical contact")
		check(app.network.tile(cell)==revealed_code,"source hidden cell revealed after continuation")
		check(not app.journey.physical_spy_handled,"completed entry clears continuation token")
		if scenario=="spy_no":
			check(app.campaign.state.posted_at(cell)==0 and app.trade.spy_slots[0]==3,"same-entry continuation cannot retrieve refused spy")
			check(not app.campaign.screen.visible,"NO cannot reopen same pickup question")
			check(app.campaign.before_entry(cell,app.journey.heading),"later separate entry asks posted spy again")
			check(app.campaign.state.pending.get("scene")=="spy_pickup","later entry retains source pickup rule")
			app.campaign._answer(false)
		check(app.journey.position==stopped_cell and app.journey.phase==stopped_phase and app.journey.distance_ticks==stopped_ticks,"continuation cannot advance TIME")
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	app.queue_free()
	await process_frame
	for error in errors: push_error(error)
	if errors.is_empty(): print("PASS: real Main special-contact spy YES/NO and wolf modal save, restore, dismissal and same-contact continuation without TIME movement")
	quit(0 if errors.is_empty() else 1)
