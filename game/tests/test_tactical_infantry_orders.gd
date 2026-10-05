extends SceneTree
# MIT. Source: ECS WDECOR32c1..3431,4229..46bb, private primary listing.
const Actors = preload("res://scripts/tactical_actors.gd")
const Combat = preload("res://scripts/tactical_combat.gd")
const Wagons = preload("res://scripts/train_wagons.gd")
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func fresh():
	var state = Combat.new()
	var rng = RandomNumberGenerator.new()
	rng.seed = 420
	state.begin(Wagons.new(),47,rng)
	state.actors.clear()
	state.charges.clear()
	state.offsets = [448,448]
	return state
func run() -> void:
	_field()
	_roof()
	_dismount()
	if failures.is_empty():
		print("PASS: ",checks," source infantry whole/partial orders, roof splits, dismount, JSON and unchanged counters/RNG")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
func _field() -> void:
	for direction in 9:
		var state = fresh()
		var actor = state.add_actor(0,30,3,5,false,-1,8)
		var initial_rng: int = state.rng.state
		check(Actors.order(state,actor,direction,5),"whole infantry selection accepts direction")
		check(actor.x == 30 and actor.y == 3 and actor.count == 5 and actor.direction == direction and state.actors.size() == 1,"whole field order changes only direction")
		check(actor.processed == -1 and state.rng.state == initial_rng,"whole order does not consume pass or RNG")
	var split = fresh()
	var actor = split.add_actor(0,30,3,5,false,-1,2)
	check(Actors.order(split,actor,2,2),"partial selection still splits")
	check(actor.count == 3 and split.actors[-1].count == 2 and split.actors[-1].x == 31,"partial field selection writes neighbor")
	var merge = fresh()
	var origin = merge.add_actor(0,30,3,5,false,-1,2)
	var target = merge.add_actor(0,31,3,3,false)
	check(Actors.order(merge,origin,2,5) and target.count == 8 and not merge.actors.has(origin),"friendly merge precedes whole direction branch")
	var enemy = fresh()
	var attacker = enemy.add_actor(0,30,3,5,false)
	enemy.add_actor(1,31,3,3,false)
	check(Actors.order(enemy,attacker,2,5) and attacker.direction == 2 and attacker.x == 30,"whole selection facing enemy orders movement without immediate transfer")
func _roof() -> void:
	for roof in 2:
		for direction in [2,6,8]:
			var state = fresh()
			var actor = state.add_actor(0,10,-1,5,false,roof,8)
			check(Actors.order(state,actor,direction,5),"whole horizontal roof order succeeds")
			check(actor.x == 10 and actor.roof == roof and actor.count == 5 and actor.direction == direction,"whole roof selection changes direction in place")
			check(actor.processed == -1,"whole roof direction preserves current pass marker")
		for direction in [2,6]:
			var state = fresh()
			var actor = state.add_actor(0,10,-1,5,false,roof,8)
			var slot := 9 if direction == 2 else 11
			check(Actors.order(state,actor,direction,2),"partial roof order splits into empty adjacent cell")
			check(actor.count == 3 and state.actors[-1].x == slot and state.actors[-1].roof == roof and state.actors[-1].count == 2,"roof slot direction matches source reverse indexing")
	var merge = fresh()
	var origin = merge.add_actor(0,10,-1,5,false,1,2)
	var target = merge.add_actor(0,9,-1,3,false,1,8)
	check(Actors.order(merge,origin,2,5) and target.count == 8 and not merge.actors.has(origin),"roof friendly merge takes precedence over whole order")
func _dismount() -> void:
	for roof in 2:
		for direction in ([0,1,7] if roof == 0 else [3,4,5]):
			for amount in [2,5]:
				var state = fresh()
				var actor = state.add_actor(0,10,-1,5,false,roof,8)
				var counters: Dictionary = state.survivors.duplicate()
				var army: Array = state.army_strength.duplicate()
				var initial_rng: int = state.rng.state
				var field_x: int = (state.offsets[roof]+304+state.center_offset())/16-10
				check(Actors.order(state,actor,direction,amount),"outward roof order dismounts selected quantity")
				var dismounted = state.actors[-1]
				check(dismounted.roof == -1 and dismounted.x == field_x and dismounted.y == (6 if roof == 0 else 0) and dismounted.count == amount and dismounted.direction == 8,"outward diagonals use original roof column and stationary infantry")
				check(actor.count == 5-amount and state.actors.has(actor) == (amount < 5),"dismount preserves partial group and clears exhausted roof cell")
				check(state.survivors == counters and state.army_strength == army and state.rng.state == initial_rng,"transfers change no persistent counters or RNG")
				var restored = Combat.new()
				check(restored.restore(JSON.parse_string(JSON.stringify(state.snapshot()))),"paused roof dismount survives ordinary JSON restore")
	for mounted in [false,true]:
		var state = fresh()
		var actor = state.add_actor(0,10,-1,5,false,0,8)
		var field_x: int = (state.offsets[0]+304+state.center_offset())/16-10
		var target = state.add_actor(0,field_x,5 if mounted else 6,3,mounted)
		check(Actors.order(state,actor,0,2) == mounted,"dismount accepts own beast footprint but blocks existing infantry")
		check(target.count == (5 if mounted else 3),"mounted dismount merges riders within source maximum")
