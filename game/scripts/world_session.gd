extends RefCounted

# MIT. Host UI wiring for source-decoded YODA mine/workshop handlers.
# Source: tasks/evidence/world-completion.md; state belongs to WorldActions.
var app
var mine_screen
var workshop
var roamer_screen
var text_accumulator := 0.0
# ALIS script.c905 wait_cycles=1; YODA16 tours/minute; engine3 minutes/cycle.
const TEXT_TICKS_PER_CYCLE := 48 # source: tasks/evidence/world-completion.md.


func attach(owner_app) -> void:
	app = owner_app
	mine_screen = preload("res://scripts/world_event_screen.gd").new()
	roamer_screen = preload("res://scripts/roamer_screen.gd").new()
	workshop = preload("res://scripts/station_workshop.gd").new()
	for screen in [mine_screen, workshop, roamer_screen]:
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		app.add_child(screen)
	roamer_screen.answer_requested.connect(_answer_roamer)
	roamer_screen.dismissed.connect(_continue_roamer)
	mine_screen.answer_requested.connect(_answer_mine)
	mine_screen.dismissed.connect(_close_mine)
	workshop.cargo_changed.connect(app._on_cargo_changed)
	workshop.depart_requested.connect(_close_workshop)
	reset()


func reset() -> void:
	text_accumulator = 0.0
	mine_screen.hide()
	roamer_screen.hide()
	workshop.hide()
	workshop.management = app.world.management
	workshop.trade = app.trade


func blocks_simulation() -> bool:
	return mine_screen.visible or workshop.visible or roamer_screen.visible


func handle_boundary() -> bool:
	var cell: Vector2i = app.journey.boundary_cell()
	var code: int = app.network.tile(cell)
	if code == 78:
		var details: Dictionary = app.world.ask_mine(cell)
		if details.is_empty():
			return false
		_pause()
		mine_screen.open_mine(details)
		return true
	if code == 65:
		_pause()
		workshop.open(app.journey.position)
		preload("res://scripts/game_audio_routes.gd").worksite(app)
		return true
	if code == 79:
		app.engine.brake = true
		app.engine.speed = 0
		app.works_dialog.inform(17) # source: TIME0x2565 -> YODA0x23a depleted mine.
		return true
	if app.journey.at_station() and app.journey.station_result() == -1:
		app.engine.brake = true
		app.engine.speed = 0
		app.works_dialog.inform(16) # source: TIME message34 -> YODA TEXTEK16.
		return true
	return false


func _pause() -> void:
	app.engine.brake = true
	app.engine.speed = 0
	app.session.paused = true
	app._boudoir_session.leave()
	app._modal.hide()
	app.instruments.hide()


func _answer_mine(accept: bool) -> void:
	if not app.world.answer_mine(accept):
		return
	if accept:
		mine_screen.show_mine_phase(app.world)
		preload("res://scripts/game_audio_routes.gd").worksite(app)
	else:
		mine_screen.hide()
		app.session.paused = false


func _close_mine() -> void:
	if app.world.advance_mine():
		mine_screen.show_mine_phase(app.world)
		if app.world.mine_phase == "result":
			text_accumulator = 0.0
			app.calendar.factor = 3 # TEXTEK0x12df..12eb.
		return
	if not app.world.close_mine():
		return
	mine_screen.hide()
	app.calendar.factor = 1
	text_accumulator = 0.0
	app.session.paused = false
	app.world_view.update_train()
	preload("res://scripts/game_audio_routes.gd").journey(app)


func _close_workshop() -> void:
	workshop.hide()
	app.journey.reverse_direction() # source: GLIEU close -> YODA0x18e3.
	app.engine.speed = 0
	app.session.paused = false
	app.world_view.update_train()
	preload("res://scripts/game_audio_routes.gd").departure(app)


func handle_key(event: InputEventKey) -> bool:
	if not blocks_simulation():
		return false
	if roamer_screen.visible:
		if event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_answer_roamer(true) if roamer_screen.question else _continue_roamer()
		elif event.physical_keycode == KEY_ESCAPE and roamer_screen.question:
			_answer_roamer(false)
	elif mine_screen.visible:
		if event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_answer_mine(true) if mine_screen.question else _close_mine()
		elif event.physical_keycode == KEY_ESCAPE and mine_screen.question:
			_answer_mine(false)
	return true


func advance_text(delta: float) -> void:
	if mine_screen.visible and app.world.mine_phase == "result":
		var interval: float = app.session.seconds_per_cycle / TEXT_TICKS_PER_CYCLE
		text_accumulator += delta
		while text_accumulator >= interval:
			text_accumulator -= interval
			app.world.mine_text_tick()
		return
	if roamer_screen.visible and app.roamers.pending == "hunt_result":
		var interval: float = app.session.seconds_per_cycle / TEXT_TICKS_PER_CYCLE
		text_accumulator += delta
		while text_accumulator >= interval:
			text_accumulator -= interval
			app.roamers.textek_tick()
		return
	if not app.works_dialog.visible:
		text_accumulator = 0.0
		return
	# Reuse the existing provisional host cadence; preserve source scheduler ratio.
	var interval: float = app.session.seconds_per_cycle / TEXT_TICKS_PER_CYCLE
	text_accumulator += delta
	while text_accumulator >= interval:
		text_accumulator -= interval
		if app.works_dialog.textek_tick():
			app.calendar.factor = 1


# TIME258a..25ee and1b09: call at player entry and after mover commits.
func encounter_roamers(cell: Vector2i, bit := 0) -> bool:
	if app.roamers.encounter(cell, app.network, app._trade_rng, bit).is_empty():
		return false
	_pause()
	app.calendar.factor = 1
	if app.roamers.pending == "herd_question" and preload("res://scripts/game_audio_routes.gd").available(app):
		app.game_audio.effect("scene1",0x92) # YODA16b3 selector1 mammoths.
	restore_roamers()
	return true

func restore_roamers() -> void:
	roamer_screen.hide()
	match app.roamers.pending:
		"nomad_question":
			roamer_screen.open_works("nomads", app.campaign.state.message(27), true)
		"herd_question":
			roamer_screen.open_works("mammoth-hunt", app.campaign.state.message(23), true)
		"hunt_commissioned":
			var text: Array = app.campaign.state.message(73)
			text.append("%d SLAVES" % app.roamers.commissioned[1])
			text.append("%d SOLDIERS" % app.roamers.commissioned[2])
			roamer_screen.open_works("mammoth-hunt", text, false)
		"hunt_result":
			var text: Array = app.campaign.state.message(83)
			roamer_screen.open_works("mammoth-hunt", [text[0],text[1]+str(app.roamers.hunt_quantity),text[2]+str(app.roamers.commissioned[0]),text[3]+str(app.roamers.caught)+text[4]], false)
		"nomad_trade":
			app._show_city(45) # presentation only: restored stock must not reroll.

func _answer_roamer(accept: bool) -> void:
	if not app.roamers.answer(accept, app._trade_rng, app.wagons):
		return
	roamer_screen.hide()
	if app.roamers.pending == "nomad_trade":
		app._open_city(45)
	elif app.roamers.pending == "hunt_commissioned":
		restore_roamers()
	else:
		app.session.paused = false

func _continue_roamer() -> void:
	if app.roamers.pending == "hunt_commissioned":
		app.roamers.finish_hunt(app.wagons)
		app.calendar.factor = 3 # TEXTEK1fee.
		app._on_cargo_changed()
		restore_roamers()
	elif app.roamers.pending == "hunt_result":
		app.roamers.close()
		roamer_screen.hide()
		app.session.paused = false

func depart_nomads() -> bool:
	if app.roamers.pending != "nomad_trade":
		return false
	app.roamers.close()
	app.journey.reverse_direction() # YODA811→864→927→18e3.
	return true
