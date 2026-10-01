extends SceneTree
# requires-native-renderer
# MIT. Authored schema9 audio state; original preference/scene rules stay separate.
const Saves=preload("res://scripts/session_saves.gd")
var errors:Array[String]=[]
func _initialize()->void:call_deferred("run")
func run()->void:
	var app=preload("res://scripts/main.gd").new()
	app.save_path_override=ProjectSettings.globalize_path("res://../.cache/audio-schema-unused.json")
	app.size=Vector2(1280,800)
	root.add_child(app)
	app.set_process(false)
	await process_frame
	await process_frame
	app.game_audio.set_process(false)
	app._restart_engine()
	app.game_audio.play_reception()
	app.game_audio.toggle_original_music()
	app.game_audio._elapsed=12.5 # authored interruption fixture, not a gameplay constant.
	var saved:Dictionary=JSON.parse_string(JSON.stringify(Saves.snapshot(app)))
	check(saved.version==9 and saved.has("audio"),"actual full schema9 carries source audio state")
	app.game_audio.reset()
	app._trade_rng.randi()
	check(Saves._restore_parsed(app,saved).ok,"schema9 valid restore")
	check(str(app._trade_rng.state)==saved.trade_rng.state,"schema9 restores independent commerce RNG cursor")
	check(canonical(app.game_audio.snapshot())==saved.audio and app.game_audio.music.playing,"disabled preference resumes prior playing score/cursor")
	_test_invalid(app,saved)
	var legacy:Dictionary=saved.duplicate(true)
	legacy.version=8
	legacy.erase("audio")
	check(Saves._restore_parsed(app,legacy).ok,"schema8 full state retained without new audio")
	check(app.game_audio.music_enabled and app.game_audio.effects_enabled and app.game_audio.current_track.is_empty(),"legacy8 resets new audio to constructor defaults")
	check(canonical(app.campaign.snapshot())==legacy.campaign and canonical(app.world.snapshot())==legacy.world,"legacy8 retains campaign/world state")
	app.game_audio.reset()
	# Runtime mixer boundary releases stopped playback before owned fixture teardown.
	await create_timer(AudioServer.get_time_to_next_mix()).timeout
	await process_frame
	app.queue_free()
	await process_frame
	for error in errors:push_error(error)
	if errors.is_empty():print("PASS: full audio9 JSON resume, legacy8 defaults, malformed/missing/null audio atomicity and commerce RNG state")
	quit(0 if errors.is_empty() else 1)
func _test_invalid(app,saved:Dictionary)->void:
	var candidates:Array=[]
	var missing:Dictionary=saved.duplicate(true)
	missing.erase("audio")
	candidates.append(missing)
	var missing_rng:Dictionary=saved.duplicate(true)
	missing_rng.erase("trade_rng")
	candidates.append(missing_rng)
	var malformed_rng:Dictionary=saved.duplicate(true)
	malformed_rng.trade_rng.state="1.5"
	candidates.append(malformed_rng)
	for value in [null,"not audio",{"version":1},{"version":1,"music_enabled":true,"effects_enabled":true,"alternate":false,"track":"unknown","elapsed":0}]:
		var broken:Dictionary=saved.duplicate(true)
		broken.audio=value
		candidates.append(broken)
	for field in ["music_enabled","elapsed"]:
		var broken:Dictionary=saved.duplicate(true)
		broken.audio[field]="invalid"
		candidates.append(broken)
	for candidate in candidates:
		candidate.session.engine.lignite=1 # ensure rejected payload cannot mutate valid base.
		var before:Dictionary=Saves.snapshot(app)
		check(not Saves._restore_parsed(app,candidate).ok,"reject malformed full audio schema")
		check(Saves.snapshot(app)==before,"complete live state unchanged by failed staged audio")
func check(value:bool,message:String)->void:
	if not value:errors.append(message)
func canonical(value:Variant)->Variant:
	return JSON.parse_string(JSON.stringify(value))
