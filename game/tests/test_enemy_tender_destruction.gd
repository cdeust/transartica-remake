extends SceneTree
# MIT. ECS WDECOR0x0bef/0x0c4b..0x0ca4: enemy tender destroys engine too.
# Owner5Oct2026 reports missing coal-target tactic during native battle40283.
const Combat = preload("res://scripts/tactical_combat.gd")
const Weapons = preload("res://scripts/tactical_weapons.gd")
const Wagons = preload("res://scripts/train_wagons.gd")
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func fresh():
	var wagons = Wagons.new()
	wagons.wagons.append([11,0,0,0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 420 # Existing tactical regression fixture.
	var state = Combat.new()
	state.begin(wagons,47,rng)
	return state

func run() -> void:
	var state = fresh()
	var gun: int = state.trains[0].size()-1
	state.offsets = [gun*64,64] # Cannon relative96 faces tender1.
	state.camera_offset = state.offsets[0]-gun*64
	var engine_roof = state.add_actor(1,1,-1,4,false,1,8)
	var tender_roof = state.add_actor(1,5,-1,4,false,1,8)
	var neighbour: Dictionary = state.trains[1][2].duplicate(true)
	for hit in 3: # Original hull3 and one damage per cannon impact22.
		state.trains[0][gun].reload = 23
		Weapons.run(state)
		Weapons.run(state)
		check(state.trains[1][1].health == 2-hit,"cannon hits actual tender")
		if hit < 2:
			check(state.trains[1][0].health == 3,"partial tender damage leaves engine intact")
	check(state.trains[1][0].health == 0,"destroyed enemy tender also destroys locomotive")
	check(engine_roof.count == 0 and tender_roof.count == 0,"both linked roof crews die")
	check(state.trains[1][2] == neighbour,"adjacent independent wagon is preserved")
	state.velocities[1] = 1
	var position: int = state.offsets[1]
	Weapons.move_trains(state)
	check(state.velocities[1] == 0 and state.offsets[1] == position,"enemy remains immobilized")
	var player = fresh()
	Weapons.destroy(player,0,2) # Own real tender follows companion1.
	check(player.trains[0][0].health == 3 and player.trains[0][1].health == 3,"own tender does not destroy locomotive halves")
	var forward = fresh()
	Weapons.destroy(forward,1,0)
	check(forward.trains[1][1].health == 0,"enemy engine still destroys its tender")
	if failures.is_empty():
		print("PASS: actual cannon tender targeting, reciprocal enemy destruction, roof crews, immobilization and own tender distinction")
		quit(0)
	else:
		for message in failures: push_error(message)
		quit(1)
