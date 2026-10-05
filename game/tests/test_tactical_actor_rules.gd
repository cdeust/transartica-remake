extends SceneTree
# MIT. Source: private ECS WDECOR offsets documented in each regression below.
const Actors = preload("res://scripts/tactical_actors.gd")
const Combat = preload("res://scripts/tactical_combat.gd")
class ScriptedCombat:
	extends Combat
	var bounds: Array[int] = []
	var rolls: Array[int] = []
	func rnd(bound: int) -> int:
		bounds.append(bound)
		return rolls.pop_front() if not rolls.is_empty() else 0
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
func fresh():
	var state = ScriptedCombat.new()
	state.trains = [[], []]
	for side in 2:
		for index in 16:
			state.trains[side].append({"class": state.Setup.MERCHANDISE, "health": 3})
	state.sweep = 0
	state.aggressiveness = 31 # Source: earned native battle40283 enemy6, not a calibration.
	return state
func run() -> void:
	_melee()
	_charges()
	_sabotage()
	_riders()
	_ui()
	if failures.is_empty():
		print("PASS: ", checks, " ECS actor-rule checks: original-strength replies, charge ownership, sabotage RNG, rider orders and UI")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
func _melee() -> void:
	#0x2657/2668→2679/2843 and22e2/22f3→2308/23c7.
	for side in 2:
		for mounted_attack in [false, true]:
			for mounted_defend in [false, true]:
				var state = fresh()
				var attacker = state.add_actor(side, 10, 3, 9, mounted_attack)
				var defender = state.add_actor(1-side, 12, 3, 3, mounted_defend)
				var reply := 1 if mounted_attack else 2
				state.rolls.assign([3, reply])
				Actors.melee(state, attacker, defender)
				check(defender.count == 0 and attacker.count == 9-reply, "eliminated target replies for both factions/beast divisors")
				check(state.bounds == [1+9/(3 if mounted_defend else 1), 1+3/(3 if mounted_attack else 1)], "two draws use original counts and source divisors")
		var roofs = fresh()
		var first = roofs.add_actor(side, 10, -1, 9, false, 0, 6)
		var second = roofs.add_actor(1-side, 11, -1, 3, false, 0, 8)
		roofs.rolls.assign([3, 2])
		Actors._roof_move(roofs, first)
		check(second.count == 0 and first.count == 7 and roofs.bounds == [10, 4], "roof collision retains eliminated defender retaliation")
	var survivors = fresh()
	var attack = survivors.add_actor(0, 10, 3, 9, false,-1,2)
	var defense = survivors.add_actor(1, 11, 3, 8, false)
	survivors.rolls.assign([3, 7])
	Actors.melee(survivors, attack, defense)
	check(attack.count == 2 and defense.count == 5 and survivors.bounds == [10, 9], "surviving defender also replies with original strength")
	check(defense.direction == 6 and attack.direction == 2, "surviving field defender turns opposite attacker")
	var roof_state = fresh()
	var roof_attack = roof_state.add_actor(0,11,-1,9,false,1,2)
	var roof_defend = roof_state.add_actor(1,10,-1,8,false,1,8)
	roof_state.rolls.assign([3,7])
	Actors._roof_move(roof_state,roof_attack)
	check(roof_defend.count == 5 and roof_defend.direction == 6, "surviving roof defender turns opposite attacker")
	check(defense.processed == survivors.sweep and roof_defend.processed == roof_state.sweep, "retaliating defenders consume their pass action")
	var sweep_state = fresh()
	sweep_state.add_actor(0,11,-1,9,false,1,2)
	sweep_state.add_actor(1,10,-1,8,false,1,8)
	sweep_state.rolls.assign([3,7])
	Actors.roof_sweep(sweep_state,1)
	check(sweep_state.bounds == [10,9], "roof defender cannot act again after same-pass retaliation")
func _charges() -> void:
	#0x2295..22e1: a differently directed friendly enemy group also reverses.
	for side in 2:
		for matching in [false, true]:
			var blocked = fresh()
			var first = blocked.add_actor(side,10,-1,3,false,1,6)
			blocked.add_actor(side,11,-1,3,false,1,6 if matching else 2)
			Actors._roof_move(blocked,first)
			check(first.x == 10 and first.direction == (2 if side == 1 and not matching else 6), "friendly roof obstruction follows source direction rule")
	#0x1db4..1e25 ownership and enemy reversal; opposite faction replaces charge.
	for side in 2:
		for delta in [-1, 1]:
			for owner in 2:
				var state = fresh()
				var actor = state.add_actor(side, 10, -1, 3, false, 1, 6 if delta > 0 else 2)
				state.charges = [{"side": 1, "slot": 10+delta, "owner": owner, "fuse": 5}]
				Actors._roof_move(state, actor)
				if owner == side:
					check(actor.x == 10 and state.charges.size() == 1, "same-owner charge blocks movement")
					check(actor.direction == (2 if delta > 0 else 6) if side == 1 else actor.direction == (6 if delta > 0 else 2), "enemy reverses while player retains direction")
				else:
					check(actor.x == 10+delta and state.charges.is_empty(), "opposing charge is overwritten by moving group")
func _sabotage() -> void:
	#1c73/1c8d vs1d83; deterministic draws test strict threshold and order.
	for crossing in [false, true]:
		for roll in [30, 31]:
			var state = fresh()
			var previous := 11 if crossing else 9
			var actor = state.add_actor(1, previous, -1, 3, false, 0, 6)
			state.rolls.assign([roll])
			Actors._roof_move(state, actor)
			check(state.bounds == [100 if crossing else 2000], "source sabotage bound and exactly one draw")
			check(state.charges.size() == (1 if roll == 30 else 0), "strict sabotage threshold on crossing and within wagon")
			if not state.charges.is_empty():
				check(state.charges[0] == {"side": 0, "slot": previous, "owner": 1, "fuse": 5}, "five-pass fuse planted in vacated cell")
	for neighbor_distance in [1, 2]:
		var state = fresh()
		var actor = state.add_actor(1, 11, -1, 3, false, 0, 6)
		state.add_actor(1, 11-neighbor_distance, -1, 3, false, 0, 6)
		Actors._roof_move(state, actor)
		check(state.charges.size() == (0 if neighbor_distance == 1 else 1), "1d13 loop writes before later matching neighbor")
	var mismatch = fresh()
	var enemy = mismatch.add_actor(1,11,-1,3,false,0,6)
	mismatch.add_actor(1,10,-1,3,false,0,2)
	Actors._roof_move(mismatch,enemy)
	check(mismatch.charges.size() == 1, "different-direction neighbor does not suppress charge")
	for vital in [mismatch.Setup.LOCOMOTIVE,mismatch.Setup.GQ,mismatch.Setup.BOUDOIR]:
		var state = fresh()
		state.trains[0][3].class = vital
		state.charges = [{"side":0,"slot":13,"owner":0,"fuse":2}]
		var actor = state.add_actor(1,11,-1,3,false,0,6)
		Actors._roof_move(state,actor)
		check(state.charges == [{"side":0,"slot":13,"owner":1,"fuse":5}], "vital entry writes forward charge and replaces previous fuse")
	var overwritten = fresh()
	overwritten.trains[0][3].class = overwritten.Setup.LOCOMOTIVE
	var saboteur = overwritten.add_actor(1,11,-1,3,false,0,6)
	var victim = overwritten.add_actor(0,13,-1,3,false,0,8)
	Actors._roof_move(overwritten,saboteur)
	check(not overwritten.actors.has(victim) and overwritten.charges.size() == 1, "vital sabotage overwrites occupied roof type")
func _riders() -> void:
	#2e87..2f06 footprint,30a3..30c2 remainder,32c1..3431 partial vs whole.
	var vectors := [Vector2i(0,-1),Vector2i(2,-1),Vector2i(2,0),Vector2i(2,2),Vector2i(0,2),Vector2i(-1,2),Vector2i(-1,0),Vector2i(-1,-1)]
	for direction in 8:
		var state = fresh()
		var beast = state.add_actor(0, 30, 2, 5, true)
		check(Actors.order(state, beast, direction, 2), "selected mounted riders can dismount")
		var rider = state.actors[-1]
		check(beast.count == 3 and not rider.mammoth and rider.count == 2 and Vector2i(rider.x,rider.y) == Vector2i(30,2)+vectors[direction], "riders appear outside2x2 footprint in each direction")
		check(state.bounds.is_empty(), "rider commands consume no random draws")
	for count in [1, 5]:
		for edge in [0, 5]:
			var state = fresh()
			state.offsets = [448, 448]
			var beast = state.add_actor(0, state.train_cell(0,2), edge, count, true)
			var direction := 1 if edge == 0 else 3
			check(Actors.order(state, beast, direction, count), "explicit diagonal mounted command boards roof")
			var rider = state.actors[-1]
			check(rider.roof == (1 if edge == 0 else 0) and rider.x == state.roof_cell(rider.roof,beast.x), "boarding uses original beast x")
			check(rider.count == (count-1 if count > 1 else 1) and beast.count == (1 if count > 1 else 0), "whole mounted selection retains one only when count exceeds one")
	for owner in 2:
		var charged = fresh()
		charged.offsets = [448,448]
		var mounted = charged.add_actor(0,charged.train_cell(0,2),5,5,true)
		var slot: int = charged.roof_cell(0,mounted.x)
		charged.charges = [{"side":0,"slot":slot,"owner":owner,"fuse":5}]
		check(Actors.order(charged,mounted,4,2) == (owner == 1), "mounted boarding permits enemy charge and blocks player charge")
		check(charged.charges.is_empty() if owner == 1 else charged.charges.size() == 1, "mounted boarding overwrites only enemy dynamite")
	var whole = fresh()
	var beast = whole.add_actor(0, 30, 2, 5, true)
	check(Actors.order(whole, beast, 2, 5) and beast.direction == 2 and whole.actors.size() == 1, "whole mounted field selection changes movement without dismounting")
	for side in 2:
		var overlap = fresh()
		var mounted = overlap.add_actor(0,30,2,5,true)
		var victim = overlap.add_actor(side,32,2,3,false)
		check(Actors.order(overlap,mounted,2,2) and not overlap.actors.has(victim), "partial mounted command overwrites occupied field cell")
		check(overlap.actors[-1].x == 32 and overlap.actors[-1].count == 2, "riders replace field actor rather than merge")
	for placement in [[30,2,2],[34,2,6],[30,3,2],[34,3,6]]:
		var fragmented = fresh()
		var mounted = fragmented.add_actor(0,placement[0],placement[1],5,true)
		fragmented.add_actor(1,32,2,3,true)
		var before := JSON.stringify(fragmented.snapshot())
		check(not Actors.order(fragmented,mounted,placement[2],2),"unsupported beast-cell overwrite is refused")
		check(JSON.stringify(fragmented.snapshot()) == before,"refused fragmented footprint preserves both beasts and counters")
	var zero = fresh()
	zero.offsets = [448,448]
	var zero_mounted = zero.add_actor(0,zero.train_cell(0,0)+1,5,5,true)
	check(Actors.order(zero,zero_mounted,4,2) and zero.actors[-1].x == 0, "explicit mounted roof command accepts source slot0")
	var rider = zero.actors[-1]
	rider.direction = 6
	Actors.roof_sweep(zero,0)
	check(rider.x == 0, "source roof sweep leaves slot0 untouched")
	# Command while paused must produce a normal JSON save, including solitary transfer.
	for count in [1, 5]:
		var live = Combat.new()
		var rng = RandomNumberGenerator.new()
		rng.seed = 420
		live.begin(load("res://scripts/train_wagons.gd").new(),47,rng)
		live.actors.clear()
		live.charges.clear()
		var mounted = live.add_actor(0,live.train_cell(0,2),5,count,true)
		check(Actors.order(live,mounted,4,count), "paused mounted roof command succeeds")
		var restored = Combat.new()
		check(restored.restore(JSON.parse_string(JSON.stringify(live.snapshot()))), "paused rider command survives normal JSON restore")
	var live_zero = Combat.new()
	var zero_rng = RandomNumberGenerator.new()
	zero_rng.seed = 420
	live_zero.begin(load("res://scripts/train_wagons.gd").new(),47,zero_rng)
	live_zero.actors.clear()
	live_zero.charges.clear()
	var sole = live_zero.add_actor(0,live_zero.train_cell(0,0)+1,5,1,true)
	check(Actors.order(live_zero,sole,4,1), "solitary explicit slot0 transfer succeeds")
	var restored_zero = Combat.new()
	check(restored_zero.restore(JSON.parse_string(JSON.stringify(live_zero.snapshot()))), "paused roof0 transfer survives normal JSON restore")
func _ui() -> void:
	var scene = load("res://scripts/tactical_scene.gd").new()
	root.add_child(scene)
	var state = fresh()
	scene.open_battle(state)
	var infantry = state.add_actor(0, 30, 2, 5, false)
	scene.selected_actor = infantry.id
	scene.group_size = 2
	var key = InputEventKey.new()
	key.physical_keycode = KEY_RIGHT
	scene.handle_key(key)
	check(infantry.direction == 2 and infantry.count == 5 and state.actors.size() == 1, "infantry arrow remains whole-group direction")
	var beast = state.add_actor(0, 40, 2, 5, true)
	scene.selected_actor = beast.id
	scene.handle_key(key)
	check(beast.count == 3 and state.actors[-1].count == 2 and not state.actors[-1].mammoth, "mounted arrow routes selected rider quantity")
	beast.count = 31
	scene.group_size = 30
	key.physical_keycode = KEY_EQUAL
	scene.handle_key(key)
	check(scene.group_size == 31, "mounted selection can reach source maximum31")
	key.physical_keycode = KEY_RIGHT
	scene.handle_key(key)
	check(beast.count == 31 and beast.direction == 2, "whole31 mounted command does not dismount30")
	scene.selected_actor = infantry.id
	scene.group_size = 30
	key.physical_keycode = KEY_EQUAL
	scene.handle_key(key)
	check(scene.group_size == 30, "ordinary infantry selection remains capped30")
	scene.free()
