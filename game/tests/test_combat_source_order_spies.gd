extends SceneTree
# MIT. WDECOR17b4..198f enemy descending weapons;59f0..5a69 spy slot scan.
const Combat = preload("res://scripts/tactical_combat.gd")
const Weapons = preload("res://scripts/tactical_weapons.gd")
const Outcome = preload("res://scripts/combat_outcome.gd")
const Wagons = preload("res://scripts/train_wagons.gd")
const EngineState = preload("res://scripts/engine_state.gd")
const Campaign = preload("res://scripts/campaign_state.gd")
class TradeStub:
	extends RefCounted
	var spy_slots: Array = []
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	_weapon_order()
	for quantity in [0,1,2]: _spies(quantity)
	_spy_hole()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: enemy descending/player ascending weapons, quantity-bound spy slot scan, zero-byte underflow and full record synchronization")
	quit(0 if failures.is_empty() else 1)

func _weapon_order() -> void:
	var state = Combat.new()
	state.trains = [[],[]]
	state.offsets = [0,0]
	state.camera_offset = 0
	for side in 2:
		for index in 3:
			state.trains[side].append({"class":2,"health":3,"quantity":0,"reload":23})
	var fired: Array = []
	state.presentation_event_requested.connect(func(event): fired.append([event.side,event.wagon]))
	Weapons.run(state)
	check(fired == [[1,2],[1,1],[1,0],[0,0],[0,1],[0,2]],"Enemy weapons descend while player weapons retain ascending order")
	for side in 2:
		for car in state.trains[side]: check(car.reload == 22,"Every eligible reload advances once")

func _spies(quantity: int) -> void:
	var wagons = Wagons.new()
	wagons.wagons.append([22,3,0,quantity])
	wagons.wagons.append([22,0,0,1]) # Source fixture: a second intact spy wagon.
	var campaign = Campaign.new()
	var trade = TradeStub.new()
	trade.spy_slots.resize(20) # WDECOR5a60 slots0..19.
	trade.spy_slots.fill(1)
	for record in campaign.spies:
		record.fill(7)
		record[0] = 1
	var original: Array = campaign.spies.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 420 # Existing tactical fixture.
	Outcome.apply_destruction(wagons,EngineState.new(),trade.spy_slots,rng)
	campaign.sync_recruits(trade) # campaign_session208 runs before spy advance209.
	var scanned := 20 if quantity == 0 else quantity
	for index in 20:
		check(trade.spy_slots[index] == (0 if index < scanned else 1),"Only source scanned slots cleared for quantity"+str(quantity))
		check(campaign.spies[index] == ([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0] if index < scanned else original[index]),"Full spy record synchronization preserves unscanned records")
	check(wagons.wagons[-1] == [22,0,0,1],"Surviving second spy wagon remains intact")
	check(wagons.wagons[-2][Wagons.QUANTITY] == 0,"Destroyed quantity cleared after signed scan")

func _spy_hole() -> void:
	var wagons = Wagons.new()
	wagons.wagons.append([22,3,0,2])
	var slots: Array = [3,1,1] # Posted first spy, aboard second/third.
	var rng := RandomNumberGenerator.new()
	rng.seed = 420
	Outcome.apply_destruction(wagons,EngineState.new(),slots,rng)
	check(slots == [3,0,1],"Source decrements quantity for each scanned slot, including posted spies")
