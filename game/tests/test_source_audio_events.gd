extends SceneTree
# requires-native-renderer
# MIT. Source scene transitions, actual host channels and tactical source callbacks.
const Tactical = preload("res://scripts/tactical_combat.gd")
const Weapons = preload("res://scripts/tactical_weapons.gd")
const Saves = preload("res://scripts/session_saves.gd")
var failures: Array[String] = []
var app
var offsets: Array[int] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	if not value:
		failures.append(description)

func _run() -> void:
	app = load("res://scripts/main.gd").new()
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/source-audio-unused.SAV")
	root.add_child(app)
	app.set_process(false)
	await process_frame
	await process_frame
	app.game_audio.set_process(false)
	var audio = app.game_audio
	audio.stop_effects()
	app.campaign._play_scene_audio("wolf")
	check(audio.samples.players[0].stream == audio._wave("scene1-1.wav") and audio.samples.loops[0] == 1,"wolf scene uses SCENE1 selector2 waveform")
	audio.stop_effects()
	app.campaign._play_scene_audio("slope")
	check(audio.samples.players[0].stream == audio._wave("scene1-2.wav") and audio.samples.loops[0] == 3,"slope uses SCENE1 selector3 triple repeat")
	audio.stop_effects()
	app.campaign._play_scene_audio("mole")
	check(audio.samples.priorities == [-128,-128,-128,-128],"SCENE4 selector2 mole has no invented randomized Oslo cue")
	app.campaign.screen.scene = "oslo"
	app.campaign.screen.show()
	seed(1) # Authored reproducible source audio RNG fixture, not a game rule.
	audio._scene_audio.advance(1.0)
	var heard := false
	for player in audio.samples.players:
		if player.playing and player.stream in [audio._wave("scene4-1.wav"),audio._wave("scene4-2.wav")]:
			heard = true
	check(heard,"SCENE4 header callback supplies original Oslo randomized sound")
	app.campaign.screen.hide()
	audio.stop_effects()
	app.works_dialog.inform(52)
	check(audio.samples.players[0].stream == audio._wave("sbal-0.wav") and audio.samples.loops[0] == 1,"actual timed bridge text52 dispatches source SBAL")
	app.works_dialog.reset()
	audio.stop_effects()
	app.roamers.herds[0][0] = app.journey.position.x-40
	app.roamers.herds[0][1] = app.journey.position.y
	check(app._world_session.encounter_roamers(app.journey.position,2),"actual mammoth presence enters source question")
	check(audio.samples.players[0].stream == audio._wave("scene1-0.wav"),"mammoth question transition dispatches source SCENE1 selector1")
	app.roamers.close()
	app._world_session.roamer_screen.hide()
	audio.stop_effects()
	var brake_before: bool = app.engine.brake
	app._boudoir_session._panel_action(5)
	check(audio.samples.priorities.has(95),"actual positive footer dispatch plays source SON3")
	app.engine.brake = brake_before
	audio.stop_effects()
	app._boudoir_session._panel_action(-1)
	check(not audio.samples.priorities.has(95),"negative footer code cannot play positive-dispatch SON3")
	_test_oslo_chime(audio)
	_test_tactical(audio)
	_test_stokers(audio)
	audio.reset()
	await create_timer(AudioServer.get_time_to_next_mix()).timeout
	app.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: native scene/footer cues, saved first-Oslo chime, tactical firing/impact and TRAIN pitch/cadence")
	quit(0 if failures.is_empty() else 1)

func _test_oslo_chime(audio) -> void:
	# Authored source-valid Oslo interruption fixture, not earned progression.
	app.campaign.state.urga_key = true
	app.campaign.state.pending = {"scene":"oslo","messages":[90],"code_input":true,"quiz_done":true}
	app.campaign._submit_code(app.campaign.state.DELIVERY_CODE)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(Saves.snapshot(app)))
	check(saved.campaign.state.pending.departure_chime,"first delivery preserves source prior-flag distinction")
	app.campaign._continue()
	check(audio.samples.players[audio.samples.priorities.find(95)].stream == audio._wave("son-3.wav"),"first successful Oslo dismissal dispatches source SON3")
	audio.stop_effects()
	var restored: Dictionary = Saves._restore_parsed(app,saved)
	check(restored.ok,"interrupted Oslo source chime marker survives staged save restoration: %s" % restored)
	var broken: Dictionary = saved.duplicate(true)
	broken.campaign.state.pending.departure_chime = "invalid"
	var before: Dictionary = Saves.snapshot(app)
	check(not Saves._restore_parsed(app,broken).ok and Saves.snapshot(app) == before,"invalid source chime marker fails atomically")
	app.campaign._continue()
	check(audio.samples.priorities.has(95) and app.campaign.state.pending.is_empty(),"resumed Oslo dismissal consumes source chime once")
	audio.stop_effects()
	app.campaign.state.pending = {"scene":"oslo","messages":[90],"code_input":true,"quiz_done":true}
	app.campaign._submit_code(app.campaign.state.DELIVERY_CODE)
	app.campaign._continue()
	check(not audio.samples.priorities.has(95),"repeat delivery cannot replay first-success SON3")
	audio.stop_effects()

func _test_tactical(audio) -> void:
	var state = Tactical.new()
	state.trains = [[{"class":state.Setup.CANNON,"health":3,"quantity":0,"reload":23}],[{"class":state.Setup.CANNON,"health":3,"quantity":0,"reload":23}]]
	app.encounters.manual_scene.set_physics_process(false)
	app.encounters.manual_scene.open_battle(state)
	state.audio_cue_requested.connect(func(offset: int):offsets.append(offset))
	Weapons.run(state)
	check(offsets == [0x60cf,0x60c3],"both cannon source onset cues precede projectile impact")
	check(audio.samples.players[audio.samples.priorities.find(60)].stream == audio._wave("wdecor-1.wav"),"tactical source signal reaches native player")
	offsets.clear()
	Weapons.run(state)
	check(offsets == [0x60db,0x60db],"source impacts play on subsequent cannon step")
	offsets.clear()
	Weapons.destroy(state,0,0)
	check(offsets == [0x60f5],"source wagon destruction cue occurs once")
	app.encounters.manual_scene.hide()
	app.encounters.manual_scene.state = null
	audio.stop_effects()

func _test_stokers(audio) -> void:
	app._restart_engine()
	app._open_panel("room")
	var controller = audio._engine_audio
	controller.advance(1.0/50)
	check(audio.samples.priorities == [-128,-128,-128,-128],"TRAIN entry stays silent with zero speed and low reserve")
	app.engine.speed = 5 # Authored movement fixture; TRAINd4 only tests positivity.
	controller.active = false
	controller.advance(1.0/50)
	check(audio.samples.players[0].stream == audio._wave("son-6.wav"),"TRAIN moving entry chooses SON8")
	app.engine.speed = 0
	app.engine.pressure_reserve = 1500 # TRAINf2 source threshold.
	controller.active = false
	controller.advance(1.0/50)
	check(audio.samples.players[0].stream == audio._wave("son-7.wav"),"TRAIN stationary high-reserve entry chooses SON2")
	app.engine.pressure_reserve = 0
	app.engine.lignite_rate = 1 # Authored normal-stoker fixture uses source rate1.
	controller.active = false
	controller.advance(1.0/50)
	var channel: int = audio.samples.priorities.find(10)
	check(channel >= 0,"actual engine entry starts TRAIN source shovel sample")
	if channel < 0:
		return
	var rate: float = audio.manifest.scripts.train.samples["0"].frequency_khz
	var pickup: float = audio.samples.players[channel].pitch_scale
	check(is_equal_approx(pickup,4.0/rate) or is_equal_approx(pickup,5.0/rate),"source pickup pitch rnd2+4")
	for tick in 9: # Source normal wait3 reaches deposit pose4 at tick10.
		controller.advance(1.0/50)
	var deposit: float = audio.samples.players[channel].pitch_scale
	check(is_equal_approx(deposit,10.0/rate) or is_equal_approx(deposit,11.0/rate),"source deposit pitch rnd2+10 at original shovel pose4")
