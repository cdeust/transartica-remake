extends SceneTree
# MIT. ECS WDECOR5aa5..5bdf captures precede5be2 coal and5cab workers.
# Seed420 is the existing tactical fixture, not a gameplay calibration.
const Combat = preload("res://scripts/tactical_combat.gd")
const Result = preload("res://scripts/tactical_result.gd")
const Wagons = preload("res://scripts/train_wagons.gd")
const EngineState = preload("res://scripts/engine_state.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func _run() -> void:
	#0x5bb9 limits capture to six; include zero, single, multiple and overflow.
	for count in [0,1,2,7]:
		_case(count)
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: ECS captures before coal/workers, captured damage, six-wagon limit, exact RNG state and exactly-once rewards")
	quit(0 if failures.is_empty() else 1)

func _case(count: int) -> void:
	var state = Combat.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 420
	var wagons = Wagons.new()
	wagons.wagons.append([5,0,0,0]) # WDECOR5cff: prison capacity60.
	state.begin(wagons,47,rng)
	state.trains[1] = []
	#0x5ab1/5abe skip dead merchandise and non-merchandise.
	state.trains[1].append({"class":5,"health":0,"quantity":0,"reload":0})
	state.trains[1].append({"class":6,"health":0,"quantity":0,"reload":0})
	for index in count:
		state.trains[1].append({"class":6,"health":1+index%3,"quantity":0,"reload":0})
	state.outcome = 1
	var oracle := RandomNumberGenerator.new()
	oracle.seed = state.rng.seed
	oracle.state = state.rng.state
	var expected: Array = []
	for index in mini(count,6):
		var kind := 17+oracle.randi_range(0,1) #5adb.
		var goods := 1+oracle.randi_range(0,15) #5b0a.
		var capacity := 40
		if goods in [2,3]: capacity = 10 #5b16 goods-2 switch;5b32.
		elif goods in [5,6,8,9]: goods = 10+oracle.randi_range(0,6) #5b3c.
		var quantity := 1+oracle.randi_range(0,(capacity/2 if kind == 17 else capacity)-1) #5b7c/5b98.
		expected.append([kind,2-index%3,goods,quantity]) #5af1:3-health.
	var n: int = state.trains[1].size()
	var coal := (n*2+oracle.randi_range(0,49))*10 #5be2.
	var workers := n*3+oracle.randi_range(0,n*3-1) #5cab.
	var engine = EngineState.new()
	engine.lignite = 0
	engine.anthracite = 0
	# Fixture has an intact tender and enough prison room for these source rolls.
	var result: Dictionary = Result.commit(state,wagons,engine)
	check(result.captured == expected,"Capture roster uses source RNG order: "+str(count))
	check(result.coal_gained == coal,"Coal follows capture draws: "+str(count))
	check(result.slaves_gained == workers,"Workers follow coal draw: "+str(count))
	check(state.rng.state == oracle.state,"Final RNG state matches source: "+str(count))
	check(result.soldiers_lost == 0 and result.mammoths_lost == 0,"Survivor redistribution follows rewards: "+str(count))
	var before: Array = wagons.snapshot()
	check(Result.commit(state,wagons,engine).is_empty() and wagons.snapshot() == before and state.rng.state == oracle.state,"Repeated commit leaves rewards and RNG unchanged: "+str(count))
