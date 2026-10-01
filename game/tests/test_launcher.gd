extends SceneTree
# requires-native-renderer
# MIT. Source-valid fixture; verifies production BERTA input and save continuations.
const Saves = preload("res://scripts/session_saves.gd")
var app
var checks := 0
var failures := 0
var save_path := ProjectSettings.globalize_path("res://../.cache/launcher-native.SAV")

func _initialize() -> void:
	OS.low_processor_usage_mode = false
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await process_frame

func mouse(code: int) -> void:
	var scene = app._boudoir_session.launcher.scene
	var logical: Vector2 = scene.HOTSPOTS[code].get_center()
	var point: Vector2 = scene.global_position+scene.canvas_rect().position+logical*scene.canvas_rect().size.x/320.0
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await process_frame

func roundtrip(label: String) -> void:
	var launcher = app._boudoir_session.launcher
	var state: Dictionary = launcher.snapshot()
	var cargo: Array = app.wagons.snapshot()
	var enemies: Dictionary = app.encounters.enemies.snapshot()
	check(Saves.save(app,save_path).ok,"production save "+label)
	check(Saves.restore(app,save_path).ok,"production restore "+label)
	check(launcher.snapshot() == state and app.wagons.snapshot() == cargo and app.encounters.enemies.snapshot() == enemies,"atomic continuation and cargo/enemies "+label)

func capture(name: String) -> void:
	app._boudoir_session.launcher.scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var colors := {}
	for x in range(0,picture.get_width(),16):
		for y in range(0,picture.get_height()*149/200,16):
			colors[picture.get_pixel(x,y)] = true
	check(colors.size() > 1,"native launcher scene has nonuniform rendered pixels")
	check(picture.save_png(ProjectSettings.globalize_path("res://../tasks/validation/launcher-"+name+"-native.png")) == OK,"capture native launcher "+name)

func run() -> void:
	root.size = Vector2i(1280,800)
	app = load("res://scripts/main.gd").new()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.save_path_override = save_path
	root.add_child(app)
	app.set_process(false)
	await process_frame
	app._restart_engine()
	var launcher = app._boudoir_session.launcher
	launcher.scene.set_physics_process(false)
	check(not launcher.open() and launcher.model == null,"source gate rejects unpurchased launcher")
	app.works_dialog.hide()
	# Source-valid equipment fixture, not proof of earned campaign economy.
	app.wagons.wagons.append([13,0,0,0])
	check(not launcher.open() and app.works_dialog.visible,"purchased launcher without missiles opens source TEXTEK15")
	app.works_dialog.hide()
	app.wagons.wagons.append([14,0,2,2])
	var origin: Vector2i = app.journey.position
	app.encounters.enemies.slots[0] = [1,origin.x-40,origin.y-7,2,0,0,0,10]
	app._boudoir_session._panel_action(9)
	check(app.game_audio.samples.priorities.has(95),"source footer click emits SON3 native priority95")
	check(launcher.scene.visible and launcher.model.phase == "aim","production panel9 opens authored launcher")
	await capture("aim")
	await mouse(102)
	check(launcher.model.bearing == 1,"native source bearing increment")
	await mouse(101)
	check(launcher.model.bearing == 0,"native source bearing decrement")
	await mouse(106)
	check(launcher.model.distance() == 51,"native source distance digit")
	for tick in 9: await mouse(106)
	check(launcher.model.distance() == 50,"native source distance digit wraps")
	check(app.game_audio.effect("berta",0x580) == -1,"former ARM helper entry has no csound and cannot play")
	await mouse(107)
	check(launcher.model.phase == "arming","native source ARM hotspot starts linkage")
	var arm_channel: int = app.game_audio.samples.priorities.find(100)
	var source_rate: float = app.game_audio.manifest.scripts.berta.samples["0"].frequency_khz
	check(arm_channel >= 0 and is_equal_approx(app.game_audio.samples.players[arm_channel].pitch_scale,3.0/source_rate),"source ARM pitch3 replaces prior click pitch5 in native mixer")
	roundtrip("arming")
	await capture("arming")
	for step in 5: launcher.advance(3.0/50.0)
	check(launcher.model.phase == "armed","five source callbacks complete arming")
	roundtrip("armed")
	await mouse(108)
	check(launcher.model.phase == "launch" and app.engine.speed == 0,"native FIRE launches and stops train")
	check(app.wagons.wagons[-1][3] == 2,"missile debit waits for report dismissal")
	if launcher.model.phase != "launch":
		app.queue_free()
		await process_frame
		quit(failures)
		return
	launcher.advance(3.0/50.0)
	await capture("launch")
	var interrupted: Dictionary = launcher.snapshot()
	check(Saves.save(app,save_path).ok,"save real launcher launch continuation")
	launcher.advance(3.0/50.0)
	check(Saves.restore(app,save_path).ok,"restore real launcher continuation")
	check(launcher.snapshot() == interrupted,"launch phase and fractional cadence restored exactly")
	var valid: Dictionary = Saves.snapshot(app)
	for malformed in [null,{"version":1,"active":true,"visible":true,"paused":false,"state":{}}]:
		var invalid := valid.duplicate(true)
		invalid.launcher = malformed
		FileAccess.open(save_path,FileAccess.WRITE).store_string(JSON.stringify(invalid))
		var before := Saves.snapshot(app)
		check(not Saves.restore(app,save_path).ok and Saves.snapshot(app) == before,"malformed launcher rejects atomically")
	var missing := valid.duplicate(true)
	missing.erase("launcher")
	FileAccess.open(save_path,FileAccess.WRITE).store_string(JSON.stringify(missing))
	check(not Saves.restore(app,save_path).ok and launcher.snapshot() == interrupted,"schema9 missing launcher rejected atomically")
	check(Saves.save(app,save_path).ok,"recover valid continuation after rejected saves")
	var named_path := ProjectSettings.globalize_path("res://../.cache/LAUNCHER.SAV")
	check(Saves.save(app,named_path).ok,"save named launcher slot")
	app._boudoir_session._load("LAUNCHER")
	check(launcher.scene.visible and launcher.snapshot() == interrupted,"production named loader presents pending launcher")
	DirAccess.remove_absolute(named_path)
	await key(KEY_F6)
	check(app._boudoir_session.reception.visible and not launcher.scene.visible and launcher.paused,"OPTIONS suspends launcher")
	app._open_panel("room")
	check(launcher.scene.visible and launcher.paused,"return resumes same paused launcher")
	await key(KEY_P)
	check(not launcher.paused,"native P resumes launcher")
	var prior_phase: String = launcher.model.phase
	while launcher.model.phase not in ["flight","report"]:
		launcher.advance(3.0/50.0)
		if launcher.model.phase != prior_phase:
			prior_phase = launcher.model.phase
			roundtrip(prior_phase)
	await capture("flight")
	while launcher.model.phase != "report":
		launcher.advance(3.0/50.0)
		if launcher.model.phase != prior_phase:
			prior_phase = launcher.model.phase
			roundtrip(prior_phase)
			if prior_phase == "impact": await capture("impact")
	check(launcher.model.status == 2 and app.encounters.enemies.slots[0] == [2,0,0,0,0,0,0,0],"source homing removes first matched enemy exactly once")
	check(app.wagons.wagons[-1][3] == 2,"report still owns delayed ammo debit")
	await capture("report")
	check(Saves.save(app,save_path).ok,"save real pending missile report")
	check(Saves.restore(app,save_path).ok,"restore pending report with removed enemy")
	var corrupt_target: Dictionary = Saves.snapshot(app)
	corrupt_target.launcher.state.geometry.record[1] = "invalid"
	FileAccess.open(save_path,FileAccess.WRITE).store_string(JSON.stringify(corrupt_target))
	var before_corrupt := Saves.snapshot(app)
	check(not Saves.restore(app,save_path).ok and Saves.snapshot(app) == before_corrupt,"malformed removed-target history rejects before geometry arithmetic")
	await key(KEY_ENTER)
	check(launcher.model == null and app.wagons.wagons[-1][3] == 1,"native report dismissal debits only one missile")
	await key(KEY_ENTER)
	check(app.wagons.wagons[-1][3] == 1,"repeated Enter cannot debit again")
	var legacy: Dictionary = Saves.snapshot(app)
	legacy.version = 8
	legacy.erase("launcher")
	check(launcher.open(),"open another source-valid launcher before legacy restore")
	FileAccess.open(save_path,FileAccess.WRITE).store_string(JSON.stringify(legacy))
	check(Saves.restore(app,save_path).ok and launcher.model == null and not launcher.scene.visible,"legacy8 resets unavailable launcher continuation")
	DirAccess.remove_absolute(save_path)
	app.game_audio.stop_effects()
	app.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: launcher native ",checks," control/audio/save/continuation assertions")
	else:
		print("FAIL: launcher native ",failures)
	quit(failures)
