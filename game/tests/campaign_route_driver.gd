extends RefCounted

# Route acceptance uses source model APIs; no position, heading, fuel or cargo
# assignment is allowed after the original TABLE initial state.
const Works = preload("res://scripts/track_works.gd")
const Quiz = preload("res://scripts/manual_quiz.gd")
var network
var journey
var campaign
var wagons
var engine = preload("res://scripts/engine_state.gd").new()
var trade = preload("res://scripts/city_trade.gd").new()
var calendar = preload("res://scripts/game_calendar.gd").new()
var stoup = preload("res://scripts/stoup_messages.gd").new()
var roamers = preload("res://scripts/world_roamers.gd").new()
var world = preload("res://scripts/world_actions.gd").new()
var planner = preload("res://tests/campaign_route_planner.gd").new()
var rng := RandomNumberGenerator.new()
var trace: Array[String] = []
var error := ""
var entered_cells := 0
var advance_calls := 0
var current_city := -1
var dialog
var replan := false
var enemies = preload("res://scripts/enemy_trains.gd").new()
var encounter_rng := RandomNumberGenerator.new()
var automatic := false
var story_ui
var gates: Dictionary = {}


func attach(context: Dictionary, tree: SceneTree) -> bool:
	network = context.network
	journey = context.journey
	campaign = context.campaign
	wagons = context.wagons
	rng.seed = 1 # reproducible test seed; not a gameplay rule.
	encounter_rng.seed = 1
	if not trade.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")):
		return false
	trade.reset(rng)
	roamers.initialize(rng,campaign.fauna)
	world.attach(journey,wagons,engine,trade,rng)
	planner.network = network
	planner.campaign = campaign
	planner.wagons = wagons
	dialog = preload("res://scripts/works_dialog.gd").new()
	dialog.journey = journey
	dialog.wagons = wagons
	dialog.rng = rng
	tree.root.add_child(dialog)
	engine.cycle_anthracite()
	engine.set_regulator(300)
	return true


func travel(target: Vector2i, city: int) -> bool:
	if journey.blocked:
		if not journey.depart_from_station():
			return _fail("Cannot depart current boundary " + journey.stop_reason)
	engine.brake = false
	current_city = -1
	var route: Array = planner.plan(journey.position,journey.heading,target,journey.phase)
	if route.is_empty():
		return _fail("No supplied-resource route to %s; frontier %s" % [target,planner.frontiers])
	for action in route:
		if journey.position != action.cell:
			return _fail("Replay diverged before action at %s, actual %s" % [action.cell,journey.position])
		if action.get("reverse",false):
			engine.brake = true
			engine.speed = 0 # YODA0x18e3 reversal prelude.
			journey.reverse_direction()
			engine.brake = false
			trace.append("MANUAL REVERSE %s" % journey.position)
			continue
		if action.switch != 0 and network.tile(action.cell) != action.switch:
			if not network.toggle_switch(action.cell):
				return _fail("Switch toggle rejected")
		while journey.position != action.next and not journey.blocked:
			if not _cycle():
				return false
			if replan:
				replan = false
				while journey.phase < 0:
					if not _cycle():return false
				return travel(target,city)
		if journey.blocked:
			if journey.at_obstacle():
				var kind := Works.kind_for(network.tile(journey.next_cell()))
				if not Works.shortage(kind,wagons).is_empty():
					return _fail("Insufficient actual works cargo at %s" % journey.next_cell())
				engine.brake = true
				engine.speed = 0 # YODA0x2318 works prelude.
				dialog.ask(network)
				dialog._accept()
				trace.append("REPAIR %s kind=%s rails-left=%d" % [journey.next_cell(),kind,Works.rails_carried(wagons)])
				dialog._close(true)
				engine.brake = false
				while journey.position != action.next and not journey.blocked:
					if not _cycle():return false
			elif action.has("station"):
				engine.brake = true
				engine.speed = 0 # YODA scene prelude stops the machine.
				trace.append("INTERMEDIATE STATION %s index=%d" % [journey.next_cell(),journey.station_result()])
				if not story_ui.city(journey.station_result()):return _fail("Source city quiz failed")
				if journey.station_result() == -1 and network.tile(journey.next_cell()) != 65:
					journey.reverse_direction() # TEXTEK16 stops; player chooses YODA0x18e3 reversal.
					engine.brake = false
					while journey.phase < 0:
						if not _cycle():return false
					trace.append("END OF TRACK: PLAYER REVERSE")
				elif not journey.depart_from_station():return _fail("Intermediate departure rejected")
				engine.brake = false
			elif action.next == target and (journey.at_station() or journey.at_reversal_event() and network.tile(target) == 65):
				if journey.at_station() and journey.station_result() != city:
					return _fail("Station lookup differs from planned actual city")
				current_city = city
				engine.brake = true
				engine.speed = 0 # Source station scene prelude.
				trace.append("ARRIVE city=%d ahead=%s from=%s day=%d fuel=%d/%d" % [city,target,journey.position,calendar.day,engine.lignite,engine.anthracite])
				if not story_ui.city(city):return _fail("Source city quiz failed")
				return true
			else:
				return _fail("Unresolved actual boundary %s tile%d at%s" % [journey.stop_reason,network.tile(journey.next_cell()),journey.next_cell()])
	return _fail("Route did not stop at actual station")


func _cycle() -> bool:
	_update_firing()
	engine.train_mass = wagons.mass()
	engine.step_cycle()
	if engine.event_pending:
		return _fail("Engine event: " + engine.event_message)
	if engine.lignite == 0 and engine.anthracite == 0 and engine.pressure_reserve < 1500 and engine.speed == 0:
		return _fail("Earned fuel exhausted below source driving pressure")
	var prior_hour: int = calendar.hour
	for event in calendar.advance_cycle():
		if event in ["bridge_open","bridge_closed"]:network.set_timed_bridge(calendar.bridge_code())
		elif event == "new_day":enemies.maybe_spawn_on_day(calendar.day,0,encounter_rng)
	if calendar.hour != prior_hour:enemies.maybe_spawn_on_hour(calendar.hour,0,encounter_rng)
	world.tick_mines(calendar.day,stoup)
	campaign.advance_spies(network,trade,stoup)
	for observation in roamers.advance(network,rng,campaign.hazards.traps):
		campaign.observe_enemy(observation.code-1,observation.cell,calendar,stoup)
	if story_ui.roamer_encounter(journey.position):
		return true
	if story_ui.advance_fauna():
		return true
	var progress: int = mini(network.progress_speed(journey.position,journey.heading,engine.speed),journey.MAX_PROGRESS_SPEED)
	if not journey.blocked and engine.speed > 0 and journey.phase + 1 >= journey.PHASES_PER_TILE and journey.distance_ticks + int(progress/20) > journey.MAX_DISTANCE_REMAINDER:
		if story_ui.roamer_encounter(journey.next_cell()):return true
		world.before_entry(journey.next_cell())
		var event: Dictionary = story_ui.before_entry(journey.next_cell())
		if not event.is_empty():
			if event.scene in ["wolf","mole"]:
				return true
			if event.scene == "whale_harpoon":
				replan = true
				trace.append("HARPOON WHALE then SOURCE REVERSE at%s" % journey.position)
				return true
			return _fail("Pending campaign pre-entry event %s at%s" % [event.scene,journey.next_cell()])
	var old: Vector2i = journey.position
	journey.advance(engine.speed)
	advance_calls += 1
	if journey.position != old:
		entered_cells += 1
		enemies.record_player_position(journey.position,network)
		enemies.sync_scripted_slot(journey.position)
		if journey.position in [Vector2i(157,68),Vector2i(152,48),Vector2i(152,66),Vector2i(151,66)]:
			gates[journey.position] = {"heading":journey.heading,"wagons":wagons.count(),"tile":network.tile(journey.position),"slot29":enemies.slots[29][0]}
			trace.append("SOURCE GATE ENTER %s heading%d wagons%d fuel%d slot29state%d" % [journey.position,journey.heading,wagons.count(),engine.lignite,enemies.slots[29][0]])
	var encountered: int = enemies.encounter_at(journey.position)
	if encountered < 0:
		var prior_cells: Array = []
		for slot in enemies.SLOT_COUNT:prior_cells.append(enemies.cell(slot))
		enemies.advance_cycle(network,encounter_rng,journey.heading)
		for slot in enemies.SLOT_COUNT:
			if enemies.is_active(slot) and enemies.cell(slot) != prior_cells[slot]:
				campaign.observe_enemy(slot,enemies.cell(slot),calendar,stoup)
		encountered = enemies.encounter_at(journey.position)
	if encountered >= 0:
		var capture := {"wagons":wagons.snapshot(),"engine":engine.snapshot(),"trade":trade.snapshot(),"journey":journey.snapshot(),"network":network.snapshot(),"calendar":calendar.snapshot(),"campaign":campaign.snapshot(),"world":world.snapshot(),"enemies":enemies.snapshot(),"encountered":encountered,"seed":str(encounter_rng.seed),"state":str(encounter_rng.state)}
		var output := FileAccess.open(ProjectSettings.globalize_path("res://../.cache/campaign-route/encounter.json"),FileAccess.WRITE)
		output.store_string(JSON.stringify(capture))
		output.close()
		if automatic:
			var result: Dictionary = story_ui.resolve_battle(encountered)
			trace.append("ACTUAL AUTO BATTLE slot%d result%s" % [encountered,result])
			if not result.won:return _fail("Source automatic battle lost")
			if enemies.slots[encountered][0] != enemies.REMOVED_STATE:return _fail("Source combat did not remove actual encountered slot: driverstate%d actualstate%d driverid%d actualid%d" % [enemies.slots[encountered][0],story_ui.encounters.enemies.slots[encountered][0],enemies.get_instance_id(),story_ui.encounters.enemies.get_instance_id()])
			return true
		return _fail("Actual enemy encounter slot%d strength%d at%s" % [encountered,enemies.slots[encountered][7],journey.position])
	return true


func _update_firing() -> void:
	# EngineState's original pressure cap and drive threshold guide lever inputs;
	# no injected heat/pressure/fuel or artificial movement speed.
	if engine.anthracite == 0:
		while engine.anthracite_rate != 0:engine.cycle_anthracite()
	if engine.lignite == 0:
		while engine.lignite_rate != 0:engine.cycle_lignite()
	if engine.pressure_reserve >= 32000:
		while engine.anthracite_rate != 0:engine.cycle_anthracite()
		while engine.lignite_rate != 0:engine.cycle_lignite()
	elif engine.pressure_reserve <= 1500:
		if engine.anthracite > 0:
			while engine.anthracite_rate != 1:engine.cycle_anthracite()
			while engine.lignite_rate != 0:engine.cycle_lignite()
		elif engine.lignite > 0:
			while engine.anthracite_rate != 0:engine.cycle_anthracite()
			while engine.lignite_rate != 1:engine.cycle_lignite()


func buy_wagon(kind: int) -> bool:
	for entry in trade.workshop_list(current_city):
		if int(entry[0]) != kind:continue
		if trade.workshop_refusal(entry,0,wagons,engine) != 0:
			return _fail("Workshop refuses required wagon%d" % kind)
		trade.buy_wagons(entry,1,wagons,engine)
		trace.append("BUY WAGON type%d city%d price%d fuel%d" % [kind,current_city,entry[1],engine.lignite])
		return true
	return _fail("Actual workshop does not sell required wagon%d" % kind)


func trade_goods(goods: int, quantity: int, mode: int) -> bool:
	return transaction(trade.offer(current_city,trade.COMMERCIAL,mode,goods),quantity)


func transaction(offer: Dictionary, quantity: int) -> bool:
	if offer.is_empty() or trade.entry_refusal(offer,wagons) != 0:
		return _fail("Missing/refused actual offer at city%d" % current_city)
	for selected in quantity:
		var refusal: int = trade.increment_refusal(offer,selected,wagons,engine)
		if refusal != 0:return _fail("Actual +1 refusal%d at city%d quantity%d" % [refusal,current_city,selected])
	trade.commit(offer,quantity,wagons,engine)
	trace.append("TRANSACT city%d goods%d quantity%d mode%d unit%d fuel%d" % [current_city,offer.goods,quantity,offer.mode,trade.price(offer),engine.lignite])
	return true


func _fail(message: String) -> bool:
	error = message
	trace.append("STOP " + message)
	return false
