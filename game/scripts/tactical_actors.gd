extends RefCounted
# MIT. WDECOR33 field/roof actions; primary offsets cited at each rule.
const Survivors = preload("res://scripts/tactical_survivors.gd")

static func free_cells(state, x: int, y: int, mammoth: bool, ignore: int = -1) -> bool:
	var span := 2 if mammoth else 1
	if x < 0 or x + span > state.columns or y < 0 or y + span > 7:
		return false
	for dx in span:
		for dy in span:
			if state.actor_at(x + dx, y + dy, -1, ignore) != null:
				return false
	return true

static func order(state, actor: Dictionary, direction: int, amount: int) -> bool:
	if amount <= 0:
		actor.direction = direction
		return true
	if amount > actor.count or amount > (31 if actor.mammoth else 30):
		return false
	if actor.roof >= 0:
		return _roof_order(state, actor, direction, amount)
	var vector: Vector2i = state.DIRECTIONS[direction]
	if actor.mammoth:
		# WDECOR0x2e87..2f06: riders dismount outside the beast's2x2 footprint.
		vector = [Vector2i(0,-1), Vector2i(2,-1), Vector2i(2,0), Vector2i(2,2), Vector2i(0,2), Vector2i(-1,2), Vector2i(-1,0), Vector2i(-1,-1), Vector2i.ZERO][direction]
	var x: int = actor.x + vector.x
	var y: int = actor.y + vector.y
	if actor.mammoth and actor.roof < 0:
		if x < 0 or x >= state.columns:
			return false
		#0x2fa2..3138: explicit rider commands board from the original x, not diagonal x.
		if y < 0 or y >= 7:
			var roof := 1 if y < 0 else 0
			var slot: int = state.roof_cell(roof, actor.x)
			#0x3051 permits slot0 for explicit orders, unlike automatic boarding.
			if slot < 0 or slot >= state.trains[roof].size() * 4 or state.actor_at(slot, -1, roof) != null:
				return false
			for charge in state.charges:
				if charge.side == roof and charge.slot == slot and charge.owner == 0:
					return false
			#0x30a3..30c2: leave one when count>1; a solitary rider may transfer.
			var riders: int = actor.count - 1 if amount == actor.count and actor.count > 1 else amount
			var boarded = state.add_actor(actor.side, slot, -1, riders, false, roof, 8)
			boarded.processed = state.sweep # WDECOR0x30ce writes neg(pass).
			actor.count -= riders
			actor.processed = state.sweep #0x30f6.
			if actor.count == 0:
				state.actors.erase(actor)
			_defuse(state, boarded)
			return true
		#0x32c1..3431: partial selection dismounts; whole selection orders the beast.
		if amount == actor.count or direction == 8:
			actor.direction = direction
			return true
		#0x32d8/32f1 write the destination directly, without a casualty routine.
		var displaced = state.actor_at(x, y)
		# Source32d8 overwrites one cell, not the whole beast's2x2 footprint.
		# Beast-cell overwrites remain unsupported; preserve the state transactionally.
		if displaced != null and displaced.mammoth:
			return false
		if displaced != null:
			state.actors.erase(displaced)
		var dismounted = state.add_actor(actor.side, x, y, amount, false, -1, direction)
		dismounted.processed = state.sweep # WDECOR0x32d8 writes neg(pass).
		actor.count -= amount
		actor.processed = state.sweep #0x3326.
		return true
	var target = state.actor_at(x, y, actor.roof)
	# WDECOR0x32c1 to335b/338f:
	# whole selections change direction; a friendly adjacent merge still takes priority.
	if not actor.mammoth and (amount == actor.count or direction == 8) and (target == null or target.side != actor.side or direction == 8):
		actor.direction = direction
		return true
	# WDECOR0x31f9,3244: merge limits31 mounted,30 infantry.
	if target != null:
		if target.side != actor.side or target.count + amount > (31 if target.mammoth else 30):
			return false
		target.count += amount
		target.processed = state.sweep # WDECOR0x320b/3256.
	elif actor.roof < 0:
		if not free_cells(state, x, y, false):
			return false
		var split = state.add_actor(actor.side, x, y, amount, false, -1, direction)
		split.processed = state.sweep #0x32d8.
	else:
		return false
	actor.count -= amount
	actor.processed = state.sweep #0x3283/333a.
	if actor.count == 0:
		state.actors.erase(actor) #0x32af clears the exhausted origin cell.
	return true

static func _roof_order(state, actor: Dictionary, direction: int, amount: int) -> bool:
	# WDECOR0x4229..42ea: horizontal roof indexing is reversed from field x.
	var vector: Vector2i = state.DIRECTIONS[direction]
	var slot: int = actor.x - vector.x
	if vector.y == 0:
		var target = state.actor_at(slot, -1, actor.roof, actor.id)
		if direction != 8 and target != null and target.side == actor.side:
			if target.count + amount > 30:
				return false
			target.count += amount
			target.processed = state.sweep #0x4361.
		elif amount == actor.count or direction == 8:
			actor.direction = direction #0x43d5 to4687/46a6: no immediate whole movement.
			return true
		else:
			if slot < 0 or slot >= state.trains[actor.roof].size() * 4:
				return false
			#0x43f5/440e overwrite the destination roof cell directly.
			if target != null:
				state.actors.erase(target)
			state.charges = state.charges.filter(func(charge): return not (charge.side == actor.roof and charge.slot == slot))
			var split = state.add_actor(actor.side, slot, -1, amount, false, actor.roof, direction)
			split.processed = state.sweep
	elif (vector.y < 0 and actor.roof == 0) or (vector.y > 0 and actor.roof == 1):
		#0x444c..44f8: outward orders use original roof slot, including diagonals.
		var x: int = (state.offsets[actor.roof] + 304 + state.center_offset()) / 16 - actor.x
		var y := 6 if actor.roof == 0 else 0
		if x < 0 or x >= state.columns:
			return false
		var target = state.actor_at(x, y)
		if target != null:
			if target.side != actor.side or not target.mammoth or target.count + amount > 31:
				return false
			target.count += amount
			target.processed = state.sweep #0x45b4.
		else:
			var dismounted = state.add_actor(actor.side, x, y, amount, false, -1, 8)
			dismounted.processed = state.sweep #0x4591/45b4.
	else:
		return false
	actor.count -= amount
	actor.processed = state.sweep #0x438e/4423/45d4.
	if actor.count == 0:
		state.actors.erase(actor) #0x43ba/45f2.
	return true

static func update(state, actor: Dictionary) -> void:
	if actor.side == 1:
		_enemy_direction(state, actor)
	var vector: Vector2i = state.DIRECTIONS[actor.direction]
	if vector == Vector2i.ZERO:
		return
	var x: int = actor.x + vector.x
	var y: int = actor.y + vector.y
	# WDECOR0x2fa2..3138: infantry crossing the edge enters the roof.
	if not actor.mammoth and (y < 0 or y >= 7):
		var side := 1 if y < 0 else 0
		var slot: int = state.roof_cell(side, actor.x)
		if slot > 0 and slot < state.trains[side].size() * 4 and state.actor_at(slot, -1, side) == null:
			actor.x = slot
			actor.y = -1
			actor.roof = side
			actor.direction = 8
			_defuse(state, actor)
		return
	var target = _collision(state, actor, x, y)
	if target != null:
		if target.side != actor.side:
			melee(state, actor, target)
		return
	if free_cells(state, x, y, actor.mammoth, actor.id):
		#0x21dc player infantry skips every other scan, enemy infantry every fourth.
		var period := (2 if actor.mammoth else 4) if actor.side == 1 else (1 if actor.mammoth else 2)
		if state.sweep % period == 0:
			actor.x = x
			actor.y = y

static func _collision(state, actor: Dictionary, x: int, y: int):
	var span := 2 if actor.mammoth else 1
	for dx in span:
		for dy in span:
			var target = state.actor_at(x + dx, y + dy, -1, actor.id)
			if target != null:
				return target
	return null

static func melee(state, attacker: Dictionary, defender: Dictionary) -> void:
	# WDECOR0x2657/2668 to2679/2843; roof0x22e2/22f3 to2308/23c7:
	# both strikes use original strengths, even after the first eliminates its target.
	var attack_count: int = attacker.count
	var defend_count: int = defender.count
	var damage: int = state.rnd(1 + attack_count / (3 if defender.mammoth else 1))
	defender.count = maxi(0, defend_count - damage)
	if defender.count > 0:
		defender.direction = (attacker.direction + 4) % 8 # WDECOR0x2731/2373.
		defender.processed = state.sweep #0x2714/2376: counterstrike consumes its action.
	attacker.count = maxi(0, attack_count - state.rnd(1 + defend_count / (3 if attacker.mammoth else 1)))
	# WDECOR0x269a/26a1 and2864/286b debit persistent survivors through d90/da3.
	Survivors.damage_actor(state, defender, defend_count)
	Survivors.damage_actor(state, attacker, attack_count)
	state.events.append({"kind": "melee", "x": attacker.x, "y": attacker.y})

static func _enemy_direction(state, actor: Dictionary) -> void:
	#0x1430/1556: chance to steer toward player train; existing direction otherwise.
	if state.rnd(500) < state.aggressiveness:
		var relative: int = state.offsets[0] + 304 - (actor.x * 16 - state.center_offset())
		var edge := 5 if actor.mammoth else 6
		if relative < 0:
			actor.direction = 6 if actor.y == edge else 5
		elif relative >= state.trains[0].size() * 64:
			actor.direction = 2 if actor.y == edge else 3
	#0x123a: transfer infantry/mounted riders onto the player's roof at upper edge.
	var edge := 5 if actor.mammoth else 6
	if actor.y == edge and state.rnd(100) < state.aggressiveness:
		var slot: int = state.roof_cell(0, actor.x) + 1 - state.rnd(3)
		if slot > 0 and slot < state.trains[0].size() * 4 and state.actor_at(slot, -1, 0) == null:
			var amount: int = state.rnd(actor.count) if actor.mammoth else actor.count
			if amount > 0:
				var boarded = state.add_actor(1, slot, -1, amount, false, 0, 2 if state.rnd(3) != 0 else 6)
				boarded.processed = state.sweep # WDECOR0x12fc writes neg(pass).
				actor.count -= amount

static func roof_sweep(state, roof: int) -> void:
	#0x1722/179a: each roof is swept once per field pass, descending slot order;
	#0x1b4b: fuses burn on every sweep.
	for charge in state.charges:
		if charge.side != roof:
			continue
		charge.fuse -= 1
		if charge.fuse == 0:
			preload("res://scripts/tactical_weapons.gd").destroy(state, roof, charge.slot / 4)
	state.charges = state.charges.filter(func(charge): return charge.fuse > 0)
	# WDECOR0x1990: descending scan stops before slot0, even after explicit boarding there.
	var roof_actors: Array = state.actors.filter(func(actor): return actor.roof == roof and actor.count > 0 and actor.x > 0)
	roof_actors.sort_custom(func(a, b): return a.x > b.x)
	for actor in roof_actors:
		if state.actors.has(actor) and actor.processed != state.sweep:
			actor.processed = state.sweep # WDECOR0x19ea compares the roof count sign.
			_roof_move(state, actor)

static func _roof_move(state, actor: Dictionary) -> void:
	if actor.side == 1 and actor.direction == 8:
		#0x1a98: stationary enemy10% left,10% right,80% stay.
		var roll: int = state.rnd(100)
		actor.direction = 6 if roll < 10 else (2 if roll < 20 else 8)
	var delta := 1 if actor.direction == 6 else (-1 if actor.direction == 2 else 0)
	if delta == 0:
		return
	var next: int = actor.x + delta
	if next <= 0 or next >= state.trains[actor.roof].size() * 4:
		if actor.side == 1:
			actor.direction = 2 if delta > 0 else 6
		return
	# WDECOR0x1db4..1e25: own dynamite blocks; enemy groups reverse away.
	for charge in state.charges:
		if charge.side == actor.roof and charge.slot == next and charge.owner == actor.side:
			if actor.side == 1:
				actor.direction = 2 if delta > 0 else 6
			return
	var target = state.actor_at(next, -1, actor.roof, actor.id)
	if target != null:
		if target.side != actor.side:
			melee(state, actor, target)
		elif actor.side == 1 and actor.direction != target.direction:
			# WDECOR0x2295..22e1: enemy groups facing different directions turn away.
			actor.direction = 2 if delta > 0 else 6
		return
	#0x1bd6: steps into free or dynamite cells (0x1dce,1e22) wait while byte8548 is set.
	if state.sweep % 2 != 0:
		return
	var previous: int = actor.x
	actor.x = next
	_defuse(state, actor)
	if actor.side == 1 and actor.roof == 0:
		# WDECOR0x1c73/1c8d and1d83: crossing rolls100; other steps roll2000.
		var crossing: bool = next / 4 != previous / 4
		if state.rnd(100 if crossing else 2000) < state.aggressiveness:
			var slot := previous
			if crossing and state.trains[0][next / 4].class in state.Setup.VITAL_CLASSES:
				slot = next + delta
			elif crossing:
				#0x1d13..1d77 writes before later comparisons; later matches cannot undo it.
				var neighbor = state.actor_at(previous - 1, -1, 0)
				if neighbor != null and neighbor.side == actor.side and neighbor.direction == actor.direction:
					return
			if slot > 0 and slot < state.trains[0].size() * 4:
				#0x1ce1/1d4a/1d92 overwrite the roof type without a casualty routine.
				var displaced = state.actor_at(slot, -1, 0)
				if displaced != null:
					state.actors.erase(displaced)
				#0x1cf8/1d59/1da1: writing the roof cell replaces any charge and resets its fuse.
				state.charges = state.charges.filter(func(charge): return not (charge.side == 0 and charge.slot == slot))
				state.charges.append({"side": 0, "slot": slot, "fuse": 5, "owner": 1})

static func _defuse(state, actor: Dictionary) -> void:
	#0x1db4: walking over opposing dynamite replaces its cell with the moving group.
	state.charges = state.charges.filter(func(charge): return not (charge.side == actor.roof and charge.slot == actor.x and charge.owner != actor.side))
