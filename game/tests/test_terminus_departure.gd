extends SceneTree
# MIT. Owner4Oct EOF emergence; exact earned12091 through actual Main staging.
const FIXTURE := "res://../reference-private/validation/terminus12091-earned.json"
var errors: Array[String]=[]
func check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var app=preload("res://scripts/main.gd").new()
	app.game_audio.effects_enabled=false
	app.game_audio.music_enabled=false
	root.add_child(app)
	app.set_process(false)
	await process_frame
	app.world_view.set_process(false)
	var saves=preload("res://scripts/session_saves.gd")
	for dismissed in [false,true]:
		check(saves.restore(app,ProjectSettings.globalize_path(FIXTURE)).ok,"restore genuine EOF snapshot")
		app.game_audio.effects_enabled=false
		app.game_audio.music_enabled=false
		var cargo=app.wagons.snapshot()
		var fuel=[app.engine.lignite,app.engine.anthracite,app.engine.pressure_reserve]
		var network=app.network.snapshot()
		check(app.journey.boundary_cell()==Vector2i(49,33),"source terminal retained before departure")
		if dismissed:
			app.works_dialog.hide()
			app.session.paused=true
			app._boudoir_session._reverse_train()
			check(app.session.paused,"saved dismissed EOF retains the player's pause")
		else:
			app.works_dialog._ok.pressed.emit()
		check(not app.works_dialog.visible and not app.journey.blocked,"EOF exits through existing station transition")
		check(app.journey.position==Vector2i(48,33) and app.journey.heading==4 and not app.journey.reverse,"locomotive emerges from source terminal heading west")
		check(app.journey.history_starts_in_station(),"wagons use existing hidden station history")
		check(app.wagons.snapshot()==cargo and [app.engine.lignite,app.engine.anthracite,app.engine.pressure_reserve]==fuel,"all cargo and driving resources retained")
		check(app.network.snapshot()==network,"no track or switch rewritten by departure")
		var poses=app.world_view.train_renderer.poses(app.world_view,app.journey,app.world_view.consist,0)
		check(poses.size()==1 and app.world_view.consist.vehicles.size()==21,"one emerging locomotive belongs to retained21vehicle consist")
		var before=app.journey.snapshot()
		check(not app.depart_from_terminus() and app.journey.snapshot()==before,"ordinary track cannot trigger terminal transition")
		app._boudoir_session._reverse_train()
		check(app.journey.position==Vector2i(48,33) and app.journey.reverse,"ordinary reverser still preserves logical position")
	app.game_audio.reset()
	app.queue_free()
	await process_frame
	for error in errors: push_error(error)
	print("PASS: earned EOF modal and dismissed-save departure reuse city emergence" if errors.is_empty() else "FAIL: EOF departure")
	quit(0 if errors.is_empty() else 1)
