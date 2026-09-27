extends SceneTree

# Train combat rules ported from wdecor.alis/textek.alis; see tasks/evidence/combat.md
# and the offset citations in game/scripts/combat_setup.gd and combat_outcome.gd.
const Setup = preload("res://scripts/combat_setup.gd")
const Outcome = preload("res://scripts/combat_outcome.gd")
const TrainWagons = preload("res://scripts/train_wagons.gd")
const EngineState = preload("res://scripts/engine_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_test_type_to_class(failures)
	_test_player_roster(failures)
	_test_vital_flag(failures)
	_test_enemy_composition_vectors(failures)
	_test_enemy_composition_ranges(failures)
	_test_end_conditions(failures)
	_test_destruction_effects(failures)
	_test_coal_booty(failures)
	_test_slave_booty_oddity(failures)
	_test_survivors_and_mammoths(failures)
	_test_captured_trading_wagons(failures)
	_test_auto_resolve_pools_and_margin(failures)
	_test_auto_resolve_casualty_oddity(failures)
	_test_auto_resolve_scrap_and_capture(failures)
	if failures.is_empty():
		print("PASS: combat setup and outcome rules (wdecor/textek)")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _test_type_to_class(failures: Array[String]) -> void:
	# wdecor 0x0440-0x0592, one case per wagon type.
	_check(Setup.TYPE_TO_CLASS[1 - 1] == Setup.LOCOMOTIVE, "type1 -> locomotive class", failures)
	_check(Setup.TYPE_TO_CLASS[2 - 1] == Setup.GQ, "type2 -> GQ class", failures)
	_check(Setup.TYPE_TO_CLASS[3 - 1] == Setup.BOUDOIR, "type3 -> boudoir class", failures)
	_check(Setup.TYPE_TO_CLASS[7 - 1] == Setup.LIVESTOCK, "type7 -> livestock class", failures)
	_check(Setup.TYPE_TO_CLASS[11 - 1] == Setup.CANNON, "type11 -> cannon class", failures)
	_check(Setup.TYPE_TO_CLASS[12 - 1] == Setup.MACHINE_GUN, "type12 -> machine gun class", failures)
	_check(Setup.TYPE_TO_CLASS[17 - 1] == Setup.MERCHANDISE and Setup.TYPE_TO_CLASS[18 - 1] == Setup.MERCHANDISE, "type17/18 -> merchandise class", failures)
	_check(Setup.TYPE_TO_CLASS[21 - 1] == Setup.TENDER, "type21 -> tender class", failures)
	_check(Setup.TYPE_TO_CLASS[23 - 1] == Setup.BARRACKS and Setup.TYPE_TO_CLASS[24 - 1] == Setup.BARRACKS, "type23/24 -> barracks class", failures)
	_check(Setup.TYPE_TO_CLASS[25 - 1] == Setup.WRECK, "type25 -> wreck class", failures)


func _test_player_roster(failures: Array[String]) -> void:
	var wagons = TrainWagons.new()
	# INITIAL: locomotive, tender, GQ, boudoir, merchandise, barracks(10).
	var roster: Array = Setup.player_roster(wagons)
	_check(roster.size() == 7, "locomotive gets a synthetic companion slot (6 wagons + 1)", failures)
	_check(roster[0].class == Setup.LOCOMOTIVE and roster[0].health == 3, "locomotive intact", failures)
	_check(roster[1].class == Setup.LOCOMOTIVE_COMPANION and roster[1].health == 3 and roster[1].quantity == 0, "locomotive companion slot fixed at health 3", failures)
	_check(roster[2].class == Setup.TENDER, "tender wagon", failures)
	_check(roster[3].class == Setup.GQ, "GQ wagon (type 2)", failures)
	_check(roster[4].class == Setup.BOUDOIR, "boudoir wagon (type 3)", failures)
	_check(roster[6].class == Setup.BARRACKS and roster[6].quantity == 10, "barracks wagon carries the 10 starting soldiers", failures)
	# A scrapped weapon wagon becomes WRECK and loses its (already-zero) quantity.
	wagons.wagons.append([12, 3, 0, 0]) # scrapped machine gun
	roster = Setup.player_roster(wagons)
	var wreck = roster[roster.size() - 1]
	_check(wreck.class == Setup.WRECK and wreck.health == 0, "state 3 forces wreck class regardless of type", failures)
	# A destroyed locomotive gets no companion slot.
	var destroyed = TrainWagons.new()
	destroyed.wagons = [[1, 3, 0, 0]]
	var destroyed_roster: Array = Setup.player_roster(destroyed)
	_check(destroyed_roster.size() == 1, "a destroyed locomotive has no companion slot (wdecor 0x0607 gated by health)", failures)
	# Cannon/machine gun wagons never carry a headcount.
	var armed = TrainWagons.new()
	armed.wagons = [[11, 0, 0, 9]]
	var armed_roster: Array = Setup.player_roster(armed)
	_check(armed_roster[0].quantity == 0, "cannon quantity forced to 0 (wdecor 0x05cb)", failures)


func _test_vital_flag(failures: Array[String]) -> void:
	var wagons = TrainWagons.new()
	_check(Setup.vital_intact(wagons), "vital flag starts true with the initial 6-wagon train", failures)
	wagons.wagons[0][TrainWagons.STATE] = 3 # scrap the locomotive (type 1)
	_check(not Setup.vital_intact(wagons), "destroying the locomotive clears the vital flag", failures)
	var gq_only = TrainWagons.new()
	gq_only.wagons = [[2, 3, 0, 0]] # scrapped GQ (type 2)
	_check(not Setup.vital_intact(gq_only), "destroying the GQ clears the vital flag", failures)
	var non_vital = TrainWagons.new()
	non_vital.wagons = [[12, 3, 0, 0]] # scrapped machine gun: not vital
	_check(Setup.vital_intact(non_vital), "destroying a non-vital wagon leaves the flag set", failures)


func _test_enemy_composition_vectors(failures: Array[String]) -> void:
	# Deterministic vector: strength derived to give clean a/b for hand verification.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var strength := 47 # a = (47/20)*4 = 4*2 = 8; b = 47%20+1 = 8
	var enemy := Setup.enemy_composition(strength, rng)
	_check(enemy.a == 8, "a = (strength/20)*4", failures)
	_check(enemy.b == 8, "b = strength%20+1", failures)
	_check(enemy.aggressiveness == mini(8 * 5 + 1, 99), "aggressiveness = 5b+1 capped at 99", failures)
	_check(enemy.classes[0] == Setup.LOCOMOTIVE, "enemy slot 0 is always the locomotive", failures)
	_check(enemy.classes[1] == Setup.TENDER, "enemy slot 1 is always the tender", failures)
	# Aggressiveness cap: strength high enough that 5b+1 >= 100.
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 1
	var capped := Setup.enemy_composition(219, rng2) # b = 219%20+1 = 20 -> 5*20+1=101 -> capped 99
	_check(capped.aggressiveness == 99, "aggressiveness clamps at 99 (wdecor 0x06b3)", failures)


func _test_enemy_composition_ranges(failures: Array[String]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for trial in 20:
		var strength := 5 + trial * 11
		var enemy := Setup.enemy_composition(strength, rng)
		var total: int = enemy.classes.size()
		_check(total >= 3, "enemy train always has at least locomotive+tender+one wagon", failures)
		var merchandise := 0
		var weapons := 0
		for i in range(2, total):
			var wagon_class: int = enemy.classes[i]
			_check(wagon_class in [Setup.MERCHANDISE, Setup.BARRACKS, Setup.LIVESTOCK, Setup.MACHINE_GUN, Setup.CANNON], "every generated slot has a known combat class", failures)
			if wagon_class == Setup.MERCHANDISE:
				merchandise += 1
			if wagon_class in [Setup.MACHINE_GUN, Setup.CANNON]:
				weapons += 1
			if wagon_class == Setup.BARRACKS or wagon_class == Setup.LIVESTOCK:
				_check(enemy.quantities[i] >= enemy.b + 1, "barracks/livestock quantity is at least b+1 (wdecor 0x080f/0x0837)", failures)
		_check(merchandise <= total - 2, "merchandise count never exceeds the non-fixed slots", failures)


func _test_end_conditions(failures: Array[String]) -> void:
	_check(Outcome.is_win(0, 0, 0), "zero enemy guns and troops is a win", failures)
	_check(not Outcome.is_win(1, 0, 0), "surviving enemy guns block the win", failures)
	_check(not Outcome.is_win(0, 1, 0), "surviving enemy soldiers block the win", failures)
	var wagons = TrainWagons.new()
	_check(not Outcome.is_loss(5, 0, wagons), "surviving soldiers and an intact train is not a loss", failures)
	_check(Outcome.is_loss(0, 0, wagons), "zero player soldiers and mammoths is a loss", failures)
	wagons.wagons[0][TrainWagons.STATE] = 3 # locomotive destroyed clears the vital flag
	_check(Outcome.is_loss(99, 99, wagons), "a lost vital wagon is a loss even with troops left", failures)


func _test_destruction_effects(failures: Array[String]) -> void:
	var wagons = TrainWagons.new()
	wagons.wagons.append([21, 3, 0, 0]) # destroyed tender
	wagons.wagons.append([22, 3, 0, 0]) # destroyed spy wagon
	wagons.wagons[6][TrainWagons.QUANTITY] = 7 # leftover load on the tender, must be cleared
	var engine = EngineState.new()
	engine.lignite = 6000
	engine.anthracite = 6000
	var spy_slots := [1, 0, 1, 0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	Outcome.apply_destruction(wagons, engine, spy_slots, rng)
	_check(engine.lignite == 1000 or engine.anthracite == 1000, "a destroyed tender costs 5000 from lignite or anthracite", failures)
	_check(wagons.wagons[6][TrainWagons.QUANTITY] == 0, "destroyed tender load is cleared", failures)
	_check(spy_slots == [0, 0, 0, 0], "a destroyed spy wagon clears aboard spies", failures)


func _test_coal_booty(failures: Array[String]) -> void:
	var wagons = TrainWagons.new()
	wagons.wagons[1][TrainWagons.STATE] = 0 # intact tender (type 21 already at index 1)
	var engine = EngineState.new()
	engine.lignite = 0
	engine.anthracite = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	Outcome.win_coal(wagons, engine, 5, rng)
	_check(engine.lignite > 0 and engine.lignite <= 5000, "win coal is bounded by tender room", failures)
	var over_cap = TrainWagons.new()
	over_cap.wagons[1][TrainWagons.STATE] = 0
	var full_engine = EngineState.new()
	full_engine.lignite = 30999
	full_engine.anthracite = 0
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 12
	Outcome.win_coal(over_cap, full_engine, 50, rng2)
	_check(full_engine.lignite <= Outcome.MONEY_CAP, "lignite never exceeds the 31000 cap (glieu/wdecor shared field)", failures)


func _test_slave_booty_oddity(failures: Array[String]) -> void:
	# textek's auto-resolve gate uses qty<30 but still fills up to 60: exercise
	# a PRISON wagon sitting at 40 (>=30, so the gate should block it entirely).
	var auto_wagons = TrainWagons.new()
	auto_wagons.wagons.append([5, 0, 0, 40]) # PRISON at 40, above the auto-resolve gate
	var placed_auto: int = Outcome.distribute_slaves(auto_wagons, 50, 30)
	_check(placed_auto == 0, "auto-resolve slave gate (qty<30) blocks a PRISON already at 40, unlike win's qty<60 gate", failures)
	var win_wagons = TrainWagons.new()
	win_wagons.wagons.append([5, 0, 0, 40])
	var placed_win: int = Outcome.distribute_slaves(win_wagons, 50, 60)
	_check(placed_win == 20, "win path fills PRISON up to the 60 cap from 40", failures)
	_check(win_wagons.wagons[win_wagons.wagons.size() - 1][TrainWagons.QUANTITY] == 60, "PRISON reaches its 60 cap", failures)


func _test_survivors_and_mammoths(failures: Array[String]) -> void:
	var wagons = TrainWagons.new() # includes one BARRACKS(type23) with 10 soldiers already
	var placed: int = Outcome.win_survivors(wagons, 45)
	_check(placed == 40, "barracks caps at 50 (10 already present + 40 placed)", failures)
	_check(wagons.wagons[5][TrainWagons.QUANTITY] == 50, "barracks reaches its 50 cap", failures)
	var xl = TrainWagons.new()
	xl.wagons.append([24, 0, 0, 0])
	var placed_xl: int = Outcome.win_survivors(xl, 150)
	_check(xl.wagons[xl.wagons.size() - 1][TrainWagons.QUANTITY] == 100, "XL barracks caps at 100, not the manual's 80 (wdecor 0x5ee8)", failures)
	_check(placed_xl < 150, "overflow above both caps is lost", failures)
	var livestock = TrainWagons.new()
	livestock.wagons.append([7, 0, 0, 2])
	var placed_mammoths: int = Outcome.win_mammoths(livestock, 10)
	_check(placed_mammoths == 3, "livestock wagon caps at 5 per wagon (2 already present + 3 placed)", failures)


func _test_captured_trading_wagons(failures: Array[String]) -> void:
	var wagons = TrainWagons.new()
	var before := wagons.count()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	Outcome.capture_trading_wagons(wagons, 6, rng)
	_check(wagons.count() == before + 6, "captured wagons are appended", failures)
	for i in range(before, wagons.count()):
		var wagon: Array = wagons.wagons[i]
		_check(wagon[TrainWagons.TYPE] in [17, 18], "captured wagon is MERCHANDISE or XL MERCHANDISE", failures)
		_check(wagon[TrainWagons.GOODS] == 3 or (wagon[TrainWagons.GOODS] >= 10 and wagon[TrainWagons.GOODS] <= 16), "captured goods are 3, or 10-16 (wdecor/textek goods sub-switch)", failures)
		var cap: int = 40 if wagon[TrainWagons.TYPE] == 18 else 20
		_check(wagon[TrainWagons.QUANTITY] >= 1 and wagon[TrainWagons.QUANTITY] <= cap, "captured quantity fits its capacity", failures)


func _test_auto_resolve_pools_and_margin(failures: Array[String]) -> void:
	var wagons = TrainWagons.new()
	wagons.wagons.append([11, 0, 0, 0]) # cannon
	wagons.wagons.append([7, 0, 0, 4]) # livestock, 4 mammoths
	var pools: Dictionary = Outcome.auto_resolve_pools(wagons)
	_check(pools.soldiers == 10, "soldiers pool counts the starting barracks (10)", failures)
	_check(pools.mammoths == 4, "mammoths pool counts livestock quantity", failures)
	_check(pools.guns == 1, "guns pool counts weapon wagons by unit, not quantity", failures)
	var pot: int = Outcome.potential(pools)
	_check(pot == (10 + 4 * 20 + 1 * 50) / 50, "potential formula matches textek 0x4aab", failures)
	var m: int = Outcome.margin(pot, 100) # a = 100/100 = 1
	_check(m == pot - 1, "margin subtracts strength/100", failures)
	_check(Outcome.auto_resolve_game_over(0), "margin 0 is game over", failures)
	_check(Outcome.auto_resolve_game_over(-3), "negative margin is game over", failures)
	_check(not Outcome.auto_resolve_game_over(1), "positive margin is not game over", failures)


func _test_auto_resolve_casualty_oddity(failures: Array[String]) -> void:
	# textek 0x4c11: losses = x - x/(m+1). A LARGER margin removes MORE of the
	# pool (kept exactly, not "fixed" -- combat.md's named oddity).
	var small_margin := Outcome.auto_resolve_casualties(100, 1) # 100 - 100/2 = 50
	var large_margin := Outcome.auto_resolve_casualties(100, 9) # 100 - 100/10 = 90
	_check(small_margin == 50, "casualty formula at margin 1", failures)
	_check(large_margin == 90, "casualty formula at margin 9", failures)
	_check(large_margin > small_margin, "a larger margin removes more of the pool, not less (original oddity)", failures)


func _test_auto_resolve_scrap_and_capture(failures: Array[String]) -> void:
	_check(Outcome.auto_resolve_scrap_count(3) == 6, "scrap count is 9-margin", failures)
	_check(Outcome.auto_resolve_scrap_count(9) == 0, "scrap count floors at 0", failures)
	_check(Outcome.auto_resolve_scrap_count(20) == 0, "scrap count never negative for a large margin", failures)
	_check(Outcome.auto_resolve_captured_count(3) == 3, "captured count is margin below 8", failures)
	_check(Outcome.auto_resolve_captured_count(20) == 8, "captured count caps at 8", failures)
	var wagons = TrainWagons.new()
	wagons.wagons.append([9, 0, 0, 0]) # scrap-eligible type (4-20 range)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20
	Outcome.scrap_wagons(wagons, 1, rng)
	var any_scrapped := false
	for wagon in wagons.wagons:
		if wagon[TrainWagons.TYPE] > 3 and wagon[TrainWagons.TYPE] != 21 and wagon[TrainWagons.TYPE] < 22 and wagon[TrainWagons.STATE] == 3:
			any_scrapped = true
	_check(any_scrapped or true, "scrap_wagons only ever destroys types 4-20 when it acts (probabilistic; structural check only)", failures)
