extends SceneTree
# MIT. WDECOR persistent stocks0957..09c6, casualties0d90..0dc7,
# signed survivor redistribution5de8..6067. Fixture starts10 soldiers/2 beasts.
const Combat = preload("res://scripts/tactical_combat.gd")
const Actors = preload("res://scripts/tactical_actors.gd")
const Weapons = preload("res://scripts/tactical_weapons.gd")
const Survivors = preload("res://scripts/tactical_survivors.gd")
const Result = preload("res://scripts/tactical_result.gd")
const Wagons = preload("res://scripts/train_wagons.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func fresh():
	var wagons = Wagons.new()
	wagons.wagons.append([7,0,0,2])
	var rng := RandomNumberGenerator.new()
	rng.seed = 420 # Existing tactical fixture seed.
	var state = Combat.new()
	state.begin(wagons,47,rng)
	return state

func mounted(state) -> Dictionary:
	check(state.deploy(0,7,1),"Deploy one actual beast")
	var beast: Dictionary = state.actors[-1]
	check(state.deploy(0,6,5),"Deploy five actual infantry")
	var soldiers: Dictionary = state.actors[-1]
	soldiers.x = beast.x-1
	soldiers.y = beast.y
	check(Actors.order(state,soldiers,2,5),"Merge infantry into mounted group")
	check(beast.count == 6 and soldiers.count == 0,"One beast carries five transferred riders")
	state.actors = state.actors.filter(func(actor): return actor.count > 0)
	return beast

func commit(state) -> Dictionary:
	state.outcome = 1
	var wagons = Wagons.new()
	wagons.wagons = state.original.duplicate(true)
	var result: Dictionary = Result.commit(state,wagons,preload("res://scripts/engine_state.gd").new())
	return {"result":result,"wagons":wagons}

func _run() -> void:
	_transfers()
	_losses()
	_capacity()
	_army()
	_restore()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: persistent survivors through mounted merge/dismount, own casualties, signed writeback, overflow, bare-beast oddity, transactional JSON/legacy restore")
	quit(0 if failures.is_empty() else 1)

func _transfers() -> void:
	var state = fresh()
	var beast := mounted(state)
	check(state.survivors == {"soldiers":10,"mammoths":2},"Deployment and mounted merge conserve stock totals")
	check(Actors.order(state,beast,6,4),"Dismount four actual riders")
	check(beast.count == 2 and state.survivors == {"soldiers":10,"mammoths":2},"Dismount conserves both persistent totals")
	var after := commit(state)
	check(after.wagons.wagons[5][Wagons.QUANTITY] == 10,"All soldiers return to barracks")
	check(after.wagons.wagons[6][Wagons.QUANTITY] == 2,"Mounted strength does not create beasts")
	check(after.result.soldiers_lost == 0 and after.result.mammoths_lost == 0,"Transfers report no casualties")

func _losses() -> void:
	var state = fresh()
	var beast := mounted(state)
	beast.count = 5
	Survivors.damage_actor(state,beast,6)
	check(state.survivors == {"soldiers":9,"mammoths":2},"Partial mounted damage loses one soldier only")
	beast.count = 0
	Survivors.damage_actor(state,beast,5)
	check(state.survivors == {"soldiers":4,"mammoths":1},"Mounted death loses remaining strength and one beast")
	var after := commit(state)
	check(after.wagons.wagons[5][Wagons.QUANTITY] == 4,"Negative remainder debits aboard soldiers")
	check(after.result.soldiers_lost == 6 and after.result.mammoths_lost == 1,"Casualty report uses persistent totals")
	var bare = fresh()
	check(bare.deploy(0,7,1),"Deploy bare beast")
	var animal: Dictionary = bare.actors[-1]
	animal.count = 0
	Survivors.damage_actor(bare,animal,1)
	check(bare.survivors == {"soldiers":9,"mammoths":1},"Source bare-beast death also debits one soldier")
	var bare_result := commit(bare)
	check(bare_result.wagons.wagons[5][Wagons.QUANTITY] == 9,"Signed stock correction follows source oddity")
	var stock = fresh()
	stock.trains[0][6].health = 0 # Actual lethal impact reaches destroy after health decrement.
	Weapons.destroy(stock,0,6)
	Weapons.destroy(stock,0,7)
	check(stock.survivors == {"soldiers":0,"mammoths":0},"Destroyed barracks and livestock debit aboard quantities")
	Weapons.destroy(stock,0,6)
	check(stock.survivors.soldiers == 0,"Cleared stock is not debited twice")

func _capacity() -> void:
	var state = fresh()
	check(state.deploy(0,6,10),"Deploy all infantry before barracks loss")
	check(state.deploy(0,7,1),"Deploy beast before livestock loss")
	Weapons.destroy(state,0,6)
	Weapons.destroy(state,0,7)
	check(state.survivors == {"soldiers":10,"mammoths":1},"Deployed troops survive transport destruction")
	var after := commit(state)
	check(after.result.soldiers_lost == 10 and after.result.mammoths_lost == 2,"Unplaced survivors count as loss after capacity overflow")
	check(state.survivors == {"soldiers":0,"mammoths":0},"Final totals exclude unplaced survivors")
	var negative = fresh()
	negative.original[5][Wagons.QUANTITY] = 0
	negative.trains[0][6].quantity = 0
	negative.initial_pools.soldiers = 0
	negative.survivors.soldiers = -1
	var underflow := commit(negative)
	check(underflow.wagons.wagons[5][Wagons.QUANTITY] == -1,"ALIS signed-byte underflow is preserved without invented clamp")
	var saved_stock = Wagons.new()
	check(saved_stock.restore(JSON.parse_string(JSON.stringify(underflow.wagons.snapshot()))),"Source negative crew stock restores next save")
	var next_battle = Combat.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 420
	next_battle.begin(saved_stock,47,rng)
	var next_restored = Combat.new()
	check(next_restored.restore(JSON.parse_string(JSON.stringify(next_battle.snapshot()))),"Subsequent battle with negative crew stock restores")
	var invalid_stock: Array = saved_stock.snapshot()
	invalid_stock[1][Wagons.QUANTITY] = -1
	check(not saved_stock.restore(invalid_stock),"Negative cargo outside crew wagons remains invalid")
	check(negative.pools(0).mammoths > 0,"Army strength remains separate from signed survivor totals")

func _restore() -> void:
	var state = fresh()
	mounted(state)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(state.snapshot()))
	var restored = Combat.new()
	check(restored.restore(saved) and restored.snapshot() == state.snapshot(),"Mounted persistent totals round trip JSON exactly")
	var bad := saved.duplicate(true)
	bad.survivors.soldiers = INF
	var before: Dictionary = restored.snapshot()
	check(not restored.restore(bad) and restored.snapshot() == before,"Invalid counters reject transactionally")
	var ambiguous := saved.duplicate(true)
	ambiguous.erase("survivors")
	ambiguous.erase("army_strength")
	check(not restored.restore(ambiguous) and restored.snapshot() == before,"Ambiguous legacy mounted history is rejected without guessing")
	var legacy = Combat.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 420
	legacy.begin(Wagons.new(),47,rng)
	var old := legacy.snapshot()
	old.erase("survivors")
	old.erase("army_strength")
	check(restored.restore(old) and restored.survivors == {"soldiers":10,"mammoths":0},"Legacy infantry-only history migrates exactly")
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var earned: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
		check(restored.restore(earned.encounters.manual),"Earned40283 combat restores without resource injection")
		check(restored.survivors == {"soldiers":41,"mammoths":0},"Earned40283 migration preserves41 soldiers")
		check(restored.army_strength == [41,34],"Earned JSON migration counts barracks, livestock and roof troops")

func _army() -> void:
	var state = fresh()
	var beast := mounted(state)
	beast.x = 40 # Source fixture places destination outside2x2 footprint.
	beast.y = 3
	check(state.deploy(0,6,5),"Deploy remaining infantry for occupied dismount")
	var displaced: Dictionary = state.actors[-1]
	displaced.x = 39
	displaced.y = 3
	var army: Array = state.army_strength.duplicate()
	check(Actors.order(state,beast,6,3),"Source dismount overwrites occupied destination")
	check(not state.actors.has(displaced),"Destination actor is replaced")
	check(state.army_strength == army and state.survivors.soldiers == 10,"Raw overwrite does not invoke casualty counters")
	var resumed = Combat.new()
	check(resumed.restore(JSON.parse_string(JSON.stringify(state.snapshot()))) and resumed.army_strength == army,"Army survives JSON despite overwritten occupancy")
	var bare = fresh()
	bare.initial_pools.soldiers = 0
	bare.survivors.soldiers = 0
	bare.trains[0][6].quantity = 0
	bare.army_strength[0] = 2 # Source fixture: two bare beasts, no soldiers.
	check(bare.deploy(0,7,1),"Deploy one of two bare beasts")
	var animal: Dictionary = bare.actors[-1]
	animal.count = 0
	Survivors.damage_actor(bare,animal,1)
	check(bare.army_strength[0] == 1 and bare.survivors.soldiers == -1 and bare.survivors.mammoths == 1,"Army loses one while separate source stock counters lose two")
	bare.check_end()
	check(bare.outcome == 0,"One remaining beast prevents premature defeat")
