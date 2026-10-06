extends SceneTree
# requires-native-renderer
# MIT. Source scene routing/input assertions, not a native waveform measurement.
const Routes=preload("res://scripts/game_audio_routes.gd")
var errors:Array[String]=[]
func _initialize()->void:call_deferred("run")
func run()->void:
	var app=preload("res://scripts/main.gd").new()
	app.size=Vector2(1280,800)
	app.save_path_override=ProjectSettings.globalize_path("res://../.cache/audio-routes-unused.json")
	root.add_child(app)
	app.set_process(false)
	await process_frame
	await process_frame
	app.game_audio.set_process(false)
	check(app.game_audio.music_manifest.tracks.size()==9,"all9 original score selections packaged")
	_test_options(app)
	_test_scenes(app)
	_test_mine(app)
	app.game_audio.reset()
	# Runtime mixer boundary releases stopped playback before owned fixture teardown.
	await create_timer(AudioServer.get_time_to_next_mix()).timeout
	await process_frame
	app.queue_free()
	await process_frame
	for error in errors:push_error(error)
	if errors.is_empty():print("PASS: original music plaque preference, new game flags, signed city selectors, mine answer/close and guarded scene routes")
	quit(0 if errors.is_empty() else 1)
func _test_options(app)->void:
	app.game_audio.reset()
	app.game_audio.play_reception()
	var before:Dictionary=app.game_audio.snapshot()
	app._open_panel("options")
	check(app.game_audio.snapshot()==before,"OPTIONS alone does not select unproved BOPRES")
	var reception=app._boudoir_session.reception
	var click=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	click.position=reception.canvas_rect().position+Vector2(64,160)*reception.canvas_rect().size/reception.CANVAS
	reception._gui_input(click)
	check(not app.game_audio.music_enabled and app.game_audio.current_track==before.track and app.game_audio.music.playing,"original music plaque leaves current score playing")
	check(not reception.music_enabled,"music OFF status shown")
	Routes.journey(app)
	Routes.worksite(app)
	check(app.game_audio.current_track==before.track,"disabled scene requests preserve current score")
	app._restart_engine()
	check(not app.game_audio.music_enabled and app.game_audio.current_track.is_empty(),"START retains preference while resetting runtime")
	Routes.toggle_music(app,reception)
	Routes.journey(app)
	check(app.game_audio.current_track=="bojeu2-0","source first journey alternate after START")
func _test_scenes(app)->void:
	for index in app.world_data.cities.size():
		var kind:int=app.world_data.cities[index].kind
		Routes.city(app,index)
		if absi(kind)==3 or index==45:
			check(app.game_audio.current_track.is_empty(),"source excluded locale")
		else:
			check(app.game_audio.current_track=="bolieu-%d" % ({1:3,2:1}.get(kind,0)),"signed original locale selector")
			app.world.visit_city(index)
			Routes.city(app,index)
			check(app.game_audio.current_track=="bolieu-0","revisited locale selects fresh source0 for negative kind")
	app._restart_engine()
	app._advance_journey()
	check(app.game_audio.current_track=="bojeu2-0","ordinary journey cycles do not restart score")
func _test_mine(app)->void:
	app._restart_engine()
	app.world.tick_mines(3)
	var cell:Vector2i=app.world.mines.mine_cell(app.world.mines.records[0])
	app.journey.position=cell-Vector2i(1,0)
	app.journey.heading=6
	app.journey.blocked=true
	app.journey.stop_reason="event site"
	var before:Dictionary=app.game_audio.snapshot()
	check(app._world_session.handle_boundary(),"actual source mine question routed")
	check(app.game_audio.snapshot()==before,"question does not select accepted-mine music")
	app._world_session._answer_mine(true)
	check(app.game_audio.current_track=="bolieu-2","accepted source mine starts worksite score")
	# TEXTEK click72 ->41 ->42 precedes result cleanup; these are separate clicks.
	app._world_session._close_mine()
	check(app.world.mine_phase=="resources" and app.game_audio.current_track=="bolieu-2","mine plaque click advances resources without restarting score")
	app._world_session._close_mine()
	check(app.world.mine_phase=="result" and app.game_audio.current_track=="bolieu-2","mine resources click reaches credited result before departure")
	app._world_session._close_mine()
	check(app.game_audio.current_track in ["bojeu-0","bojeu-1"],"source mine close resumes next journey selection")
	var closed:Dictionary=app.game_audio.snapshot()
	app._world_session._close_mine()
	check(app.game_audio.snapshot()==closed,"duplicate close does not restart music")
func check(value:bool,message:String)->void:
	if not value:errors.append(message)
