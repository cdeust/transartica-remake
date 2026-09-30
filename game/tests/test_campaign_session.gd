extends SceneTree

# Real app integration gate. Root wires CampaignSession at the composition root.
const Saves = preload("res://scripts/session_saves.gd")
var failures: Array[String] = []

func _initialize() -> void:
	OS.low_processor_usage_mode = false
	call_deferred("_run")

func _run() -> void:
	var app = load("res://scripts/main.gd").new()
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/campaign-session-auto.json")
	app.size = Vector2(1280, 800) # Project viewport fixture, independent of game rules.
	root.add_child(app)
	app.set_process(false)
	await process_frame
	app._restart_engine()
	var campaign = app.campaign
	_check(campaign.state.data.has("regions"), "private ECS campaign data available in real app")
	app.journey.position = Vector2i(10, 10)
	app.journey.heading = 6
	app.journey.phase = 2
	app.journey.distance_ticks = 23
	app.engine.speed = 0
	app._advance_journey()
	_check(not campaign.screen.visible and campaign.state.pending.is_empty(), "parked adjacent whale does not trigger entry event")
	app._restart_engine()
	campaign.station(-3)
	_check(not campaign.screen.entering_code and not campaign.state.submit_code("58947").accepted, "real app Oslo without Urga key stays locked")
	campaign.reset()
	_check(campaign.station(-2), "Urga station handled")
	_check(campaign.screen.visible and app.engine.brake and app.session.paused, "original illustrated encounter stops train")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_ENTER
	app._unhandled_key_input(key)
	_check(campaign.page == 1 and campaign.screen.lines == campaign.state.message(87), "native Return advances Urga key dialogue")
	app._unhandled_key_input(key)
	_check(not campaign.screen.visible and campaign.state.urga_key, "Urga completion restores gameplay")
	campaign.station(-4)
	_check(campaign.screen.lines == campaign.state.message(51), "mausoleum shows exact ECS number")
	app._unhandled_key_input(key)
	campaign.station(-3)
	app._unhandled_key_input(key)
	_check(campaign.screen.scene == "manual_quiz", "Oslo runs original Viking manual control before CODE")
	var answer: String = campaign.state.data.quizzes.viking[campaign.state.pending.index].answer
	for letter in answer:
		key.physical_keycode = KEY_A + letter.unicode_at(0) - 65
		key.unicode = letter.unicode_at(0)
		app._unhandled_key_input(key)
	key.physical_keycode = KEY_ENTER
	key.unicode = 0
	app._unhandled_key_input(key)
	_check(campaign.screen.scene == "oslo" and campaign.screen.entering_code, "manual word answer resumes story CODE")
	for digit in "589":
		key.physical_keycode = KEY_0 + int(digit)
		key.unicode = digit.unicode_at(0)
		app._unhandled_key_input(key)
	_check(campaign.screen.input_code == "589", "native keyboard enters delivery prefix")
	var path := ProjectSettings.globalize_path("res://../.cache/campaign-interrupted.SAV")
	_check(Saves.save(app, path).ok, "partial Oslo interaction saved")
	campaign.reset()
	_check(Saves.restore(app, path).ok, "full app interrupted save restores")
	_check(campaign.screen.visible and campaign.screen.entering_code and campaign.screen.input_code == "589", "code input and current scene resume exactly")
	for digit in "47":
		key.physical_keycode = KEY_0 + int(digit)
		key.unicode = digit.unicode_at(0)
		app._unhandled_key_input(key)
	key.physical_keycode = KEY_ENTER
	key.unicode = 0
	app._unhandled_key_input(key)
	_check(campaign.state.delivery_open and app.stoup.has_pending(), "native delivery validation unlocks counter and SOS")
	app._unhandled_key_input(key)
	campaign.station(-5)
	app._unhandled_key_input(key)
	_check(campaign.screen.visible and campaign.screen.scene == "sun-restored", "ending visibly changes clouded world")
	app._unhandled_key_input(key)
	_check(app._boudoir_session.reception.visible, "ending returns to reception")
	campaign.reset()
	campaign.die(104)
	_check(campaign.screen.visible and campaign.screen.lines == campaign.state.message(104, true), "death cause gets correct epitaph")
	app._unhandled_key_input(key)
	_check(campaign.screen.scene == "earth", "death first presents original Earth scene")
	app._unhandled_key_input(key)
	_check(app._boudoir_session.reception.visible, "death returns to reception")
	DirAccess.remove_absolute(path)
	app.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: real app Urga/mausoleum/Oslo keyboard input, interrupted save-resume, visible Sun finale and correct death")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
