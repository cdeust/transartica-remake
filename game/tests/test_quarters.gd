extends SceneTree

const StoupMessages = preload("res://scripts/stoup_messages.gd")
const InventoryReport = preload("res://scripts/inventory_report.gd")
const QuartersActions = preload("res://scripts/quarters_actions.gd")
const BoudoirActions = preload("res://scripts/boudoir_actions.gd")
const PanelHotspots = preload("res://scripts/panel_hotspots.gd")
const TrainWagons = preload("res://scripts/train_wagons.gd")
const EngineState = preload("res://scripts/engine_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_test_stoup_messages(failures)
	_test_inventory_report(failures)
	_test_quarters_actions(failures)
	_test_boudoir_actions(failures)
	_test_panel_hotspots(failures)
	if failures.is_empty():
		print("PASS: stoup queue, inventory report, quarters/boudoir menus, panel hotspots")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_stoup_messages(failures: Array[String]) -> void:
	var stoup := StoupMessages.new()
	if stoup.has_pending():
		failures.append("stoup: empty queue reports pending")
	for i in range(StoupMessages.CAPACITY):
		stoup.push(100 + i)
	if stoup.count() != StoupMessages.CAPACITY:
		failures.append("stoup: count %d != capacity" % stoup.count())
	# Overflow: pushing an 11th message drops the oldest (100), keeps 101..109 + 200.
	stoup.push(200)
	if stoup.count() != StoupMessages.CAPACITY:
		failures.append("stoup: overflow changed count")
	# LIFO read: the most recently pushed (200) comes back first.
	var first := stoup.pop()
	if first.message_id != 200 or first.display != StoupMessages.STOUP_DISPLAY:
		failures.append("stoup: expected LIFO pop of 200, got %s" % [first])
	var second := stoup.pop()
	if second.message_id != 109:
		failures.append("stoup: expected 109 after 200, got %s" % [second])
	# The oldest entry (100) must have been dropped by the earlier overflow.
	var remaining: Array = stoup.snapshot()
	if remaining.has(100):
		failures.append("stoup: oldest entry (100) survived overflow")
	var drained := StoupMessages.new()
	if not drained.pop().is_empty():
		failures.append("stoup: pop on empty queue did not return {}")


func _test_inventory_report(failures: Array[String]) -> void:
	var wagons := TrainWagons.new()
	wagons.reset()
	var engine := EngineState.new()
	engine.lignite = 300
	engine.anthracite = 50
	# INITIAL: [1,21,2,3,17,23(qty 10)]. None destroyed, no tender load beyond the base.
	var expected_ptav := 0
	for wagon in wagons.wagons:
		expected_ptav += TrainWagons.BASE_WEIGHT[wagon[TrainWagons.TYPE] - 1]
	if InventoryReport.ptav(wagons) != expected_ptav:
		failures.append("inventory: ptav %d != expected %d" % [InventoryReport.ptav(wagons), expected_ptav])
	# One intact TENDER (type 21) adds lignite+anthracite; the SOLDIER wagon (type 23,
	# qty 10) adds quantity/10 = 1 (train_wagons.gd's own load-weight bucket, matched
	# by textek.alis 0x37ba). Both fold into PTAC on top of PTAV.
	var expected_ptac := expected_ptav + engine.lignite + engine.anthracite + 1
	if InventoryReport.ptac(wagons, engine) != expected_ptac:
		failures.append("inventory: ptac %d != expected %d" % [InventoryReport.ptac(wagons, engine), expected_ptac])
	if InventoryReport.tender_capacity(wagons) != 5000:
		failures.append("inventory: tender_capacity %d != 5000 for one intact tender" % InventoryReport.tender_capacity(wagons))
	if InventoryReport.present_contents(engine) != 350:
		failures.append("inventory: present_contents %d != 350" % InventoryReport.present_contents(engine))
	if InventoryReport.destroyed_count(wagons) != 0:
		failures.append("inventory: destroyed_count %d != 0 on a fresh train" % InventoryReport.destroyed_count(wagons))
	# Destroy the tender: PTAV drops to a flat 10 for it, PTAC loses its fuel term and
	# tender_capacity drops to 0.
	for wagon in wagons.wagons:
		if wagon[TrainWagons.TYPE] == 21:
			wagon[TrainWagons.STATE] = 3
	var expected_ptav_destroyed := expected_ptav - TrainWagons.BASE_WEIGHT[20] + 10
	if InventoryReport.ptav(wagons) != expected_ptav_destroyed:
		failures.append("inventory: ptav after destroying tender %d != %d" % [InventoryReport.ptav(wagons), expected_ptav_destroyed])
	# No fuel term once the tender is destroyed, but the SOLDIER wagon still adds 1.
	var expected_ptac_destroyed := expected_ptav_destroyed + 1
	if InventoryReport.ptac(wagons, engine) != expected_ptac_destroyed:
		failures.append("inventory: ptac after destroying tender %d != %d" % [InventoryReport.ptac(wagons, engine), expected_ptac_destroyed])
	if InventoryReport.tender_capacity(wagons) != 0:
		failures.append("inventory: tender_capacity %d != 0 once the tender is destroyed" % InventoryReport.tender_capacity(wagons))
	if InventoryReport.destroyed_count(wagons) != 1:
		failures.append("inventory: destroyed_count %d != 1" % InventoryReport.destroyed_count(wagons))
	# Type lines: SOLDIER wagon (type 23) carries 10, contents suffix SOLDIER(S).
	var lines := InventoryReport.type_lines(wagons, null)
	var soldier_line: Dictionary = {}
	for line in lines:
		if line.type == 23:
			soldier_line = line
	if soldier_line.is_empty() or soldier_line.count != 1 or soldier_line.contents != "SOLDIER(S)":
		failures.append("inventory: soldier type line missing or wrong: %s" % [soldier_line])
	var header := InventoryReport.header(42, wagons, 2)
	if header.day != 42 or header.page != 2 or header.wagon_count != wagons.count() or header.destroyed != 1:
		failures.append("inventory: header mismatch: %s" % [header])


func _test_quarters_actions(failures: Array[String]) -> void:
	var wagons := TrainWagons.new()
	wagons.reset()
	var spies: Array = []
	spies.resize(QuartersActions.SPY_SLOT_COUNT)
	spies.fill(QuartersActions.STATE_FREE)
	var stoup := StoupMessages.new()

	# No spy records at all -> spy menu code shows the "no spies" textek.
	var no_spies := QuartersActions.dispatch(QuartersActions.SPY_MENU_CODE, wagons, spies, stoup)
	if no_spies.get("kind") != "textek" or no_spies.get("id") != QuartersActions.NO_SPIES_TEXTEK:
		failures.append("quarters: expected NO_SPIES_TEXTEK, got %s" % [no_spies])

	spies[3] = QuartersActions.STATE_ABOARD
	if not QuartersActions.can_send_spy(spies):
		failures.append("quarters: aboard spy should allow sending")
	if QuartersActions.can_dynamite(spies):
		failures.append("quarters: aboard-only spy should not allow dynamite")
	var send_result := QuartersActions.spy_menu_action(QuartersActions.SPY_MENU_SEND_CODE, spies)
	if send_result.get("id") != QuartersActions.SEND_SPY_YODA_MSG:
		failures.append("quarters: send spy did not yield yoda msg 12: %s" % [send_result])
	# Dynamite not available yet: action is a silent no-op.
	if not QuartersActions.spy_menu_action(QuartersActions.SPY_MENU_DYNAMITE_CODE, spies).is_empty():
		failures.append("quarters: dynamite fired without a travelling/posted spy")

	spies[3] = QuartersActions.STATE_TRAVELLING
	if not QuartersActions.can_dynamite(spies):
		failures.append("quarters: travelling spy should allow dynamite")
	var spy_menu := QuartersActions.dispatch(QuartersActions.SPY_MENU_CODE, wagons, spies, stoup)
	if spy_menu.get("kind") != "spy_menu":
		failures.append("quarters: spy menu should open once a spy is travelling: %s" % [spy_menu])

	# No line-inspection cars (GOODS 3) -> the car menu code shows textek 8.
	var no_cars := QuartersActions.dispatch(QuartersActions.CAR_MENU_CODE, wagons, spies, stoup)
	if no_cars.get("kind") != "textek" or no_cars.get("id") != QuartersActions.NO_CARS_TEXTEK:
		failures.append("quarters: expected NO_CARS_TEXTEK, got %s" % [no_cars])
	# Add a plain car (type 17, GOODS 3) and a missile car (type 18, GOODS 2, per
	# train_wagons.gd's RAIL_WAGONS/city_trade goods vocabulary reused here as data).
	wagons.wagons.append([17, 0, 3, 4])
	var car_menu := QuartersActions.dispatch(QuartersActions.CAR_MENU_CODE, wagons, spies, stoup)
	if car_menu.get("kind") != "car_menu":
		failures.append("quarters: car menu should open with a GOODS==3 car present: %s" % [car_menu])
	if not QuartersActions.car_menu_action(QuartersActions.CAR_MENU_MISSILE_CODE, wagons).is_empty():
		failures.append("quarters: missile car fired with no GOODS==2 wagon")
	var plain := QuartersActions.car_menu_action(QuartersActions.CAR_MENU_PLAIN_CODE, wagons)
	if plain.get("id") != QuartersActions.PLAIN_CAR_YODA_MSG:
		failures.append("quarters: plain car action did not yield yoda msg 10: %s" % [plain])
	wagons.wagons.append([18, 0, 2, 2])
	var missile := QuartersActions.car_menu_action(QuartersActions.CAR_MENU_MISSILE_CODE, wagons)
	if missile.get("id") != QuartersActions.MISSILE_CAR_YODA_MSG:
		failures.append("quarters: missile car action did not yield yoda msg 11: %s" % [missile])

	# Stoup: no-op when nothing pending, "stoup" kind once a message is pushed.
	if not QuartersActions.dispatch(QuartersActions.STOUP_CODE, wagons, spies, stoup).is_empty():
		failures.append("quarters: stoup fired with an empty queue")
	stoup.push(98)
	if QuartersActions.dispatch(QuartersActions.STOUP_CODE, wagons, spies, stoup).get("kind") != "stoup":
		failures.append("quarters: stoup did not fire with a pending message")

	var map_result := QuartersActions.dispatch(QuartersActions.MAP_CODE, wagons, spies, stoup)
	if map_result.get("id") != QuartersActions.OVERALL_MAP_YODA_MSG:
		failures.append("quarters: map code did not yield yoda msg 1: %s" % [map_result])


func _test_boudoir_actions(failures: Array[String]) -> void:
	var stoup := StoupMessages.new()
	if not BoudoirActions.dispatch(BoudoirActions.STOUP_CODE, stoup).is_empty():
		failures.append("boudoir: stoup fired with an empty queue")
	stoup.push(98)
	if BoudoirActions.dispatch(BoudoirActions.STOUP_CODE, stoup).get("kind") != "stoup":
		failures.append("boudoir: stoup did not fire with a pending message")

	var kolotov := BoudoirActions.dispatch(BoudoirActions.KOLOTOV_CODE, stoup)
	if kolotov.get("kind") != "inventory" or kolotov.get("message") != BoudoirActions.KOLOTOV_MESSAGE:
		failures.append("boudoir: kolotov dispatch wrong: %s" % [kolotov])

	var revolver := BoudoirActions.dispatch(BoudoirActions.REVOLVER_CODE, stoup)
	if revolver.get("kind") != "revolver_prompt" or revolver.get("message") != BoudoirActions.REVOLVER_PROMPT:
		failures.append("boudoir: revolver dispatch wrong: %s" % [revolver])
	var confirmed := BoudoirActions.revolver_confirm()
	if confirmed.get("epitaph_id") != BoudoirActions.EPITAPH_SUICIDE or confirmed.get("yoda_msg") != BoudoirActions.GAME_OVER_YODA_MSG:
		failures.append("boudoir: revolver confirm wrong: %s" % [confirmed])
	if not BoudoirActions.revolver_cancel().is_empty():
		failures.append("boudoir: revolver cancel should be a no-op")

	var book := BoudoirActions.dispatch(BoudoirActions.BOOK_CODE, stoup)
	if book.get("kind") != "save_prompt":
		failures.append("boudoir: book dispatch wrong: %s" % [book])

	# Name entry: lowercase folds to uppercase, backspace works, length is capped at 8,
	# non-alnum keys are ignored, and 187 is recognised as confirm (not appended).
	var name := ""
	for key in [104, 101, 108, 108, 111, 33, 33, 33]: # "hello" then 3 stray keys (33 = '!')
		name = BoudoirActions.append_char(name, key)
	if name != "HELLO":
		failures.append("boudoir: name folding/filtering wrong: %s" % name)
	name = BoudoirActions.append_char(name, BoudoirActions.BACKSPACE_KEY)
	if name != "HELL":
		failures.append("boudoir: backspace wrong: %s" % name)
	for key in [65, 66, 67, 68, 69, 70, 71, 72, 73, 74]: # try to overflow past 8 chars
		name = BoudoirActions.append_char(name, key)
	if name.length() != BoudoirActions.NAME_MAX_LEN:
		failures.append("boudoir: name exceeded NAME_MAX_LEN: %s" % name)
	if BoudoirActions.is_confirm(BoudoirActions.CONFIRM_KEY) != true:
		failures.append("boudoir: CONFIRM_KEY not recognised")

	var saved := BoudoirActions.build_save(name, {"version": 7, "wagons": []})
	if saved.get("filename") != ("%s.SAV" % name) or not saved.has("data"):
		failures.append("boudoir: build_save wrong: %s" % [saved])
	if not BoudoirActions.build_save("", {"version": 7}).is_empty():
		failures.append("boudoir: build_save with an empty name should refuse")


func _test_panel_hotspots(failures: Array[String]) -> void:
	if PanelHotspots.selected_wagon_index(PanelHotspots.CODE_WAGON_C) != 3:
		failures.append("panel: selected_wagon_index(8) != 3")
	var clock_on := PanelHotspots.clock_toggle(false)
	if not clock_on.accelerated or clock_on.time_step != 3:
		failures.append("panel: clock_toggle(off->on) wrong: %s" % [clock_on])
	var clock_off := PanelHotspots.clock_toggle(true)
	if clock_off.accelerated or clock_off.time_step != 1:
		failures.append("panel: clock_toggle(on->off) wrong: %s" % [clock_off])
	var brake_on := PanelHotspots.brake_toggle(false)
	if not brake_on.braking:
		failures.append("panel: brake_toggle(off->on) wrong: %s" % [brake_on])
	# Codes 3-5 are disassembly-proven no-ops in a wagon/city view.
	for code in [PanelHotspots.CODE_REVERSER, PanelHotspots.CODE_DETAILED_MAP, PanelHotspots.CODE_BRAKE]:
		if PanelHotspots.WAGON_CITY_ACTIONS[code] != "":
			failures.append("panel: code %d should be a no-op in a wagon/city view" % code)
	if not PanelHotspots.launcher_action(false, 5).is_empty():
		failures.append("panel: launcher fired without main+0x62c1 (bought)")
	var no_missiles := PanelHotspots.launcher_action(true, 0)
	if no_missiles.get("kind") != "textek" or no_missiles.get("id") != PanelHotspots.NO_MISSILES_TEXTEK:
		failures.append("panel: launcher with 0 missiles should show textek 15: %s" % [no_missiles])
	var opened := PanelHotspots.launcher_action(true, 3)
	if opened.get("kind") != "scene" or opened.get("id") != PanelHotspots.LAUNCHER_SCENE:
		failures.append("panel: launcher with missiles should open scene -2: %s" % [opened])
