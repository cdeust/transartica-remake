extends RefCounted
# MIT. WDECOR33 field/roof actions; primary offsets cited at each rule.

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
	if amount > actor.count or amount > 30 or actor.mammoth:
		return false
	var vector: Vector2i = state.DIRECTIONS[direction]
	var x: int = actor.x + vector.x
	var y: int = actor.y + vector.y
	var target = state.actor_at(x, y, actor.roof)
	# WDECOR0x31f9,3244: merge limits31 mounted,30 infantry.
	if target != null:
		if target.side != actor.side or target.count + amount > (31 if target.mammoth else 30):
			return false
		target.count += amount
	elif actor.roof < 0:
		if not free_cells(state, x, y, false):
			return false
		state.add_actor(actor.side, x, y, amount, false, -1, direction)
	else:
		return false
	actor.count -= amount
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
	# WDECOR0x2679/2843: survivors answer, divisor3 against a mammoth.
	var damage: int = state.rnd(1 + attacker.count / (3 if defender.mammoth else 1))
	defender.count = maxi(0, defender.count - damage)
	if defender.count > 0:
		attacker.count = maxi(0, attacker.count - state.rnd(1 + defender.count / (3 if attacker.mammoth else 1)))
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
				state.add_actor(1, slot, -1, amount, false, 0, 2 if state.rnd(3) != 0 else 6)
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
	var roof_actors: Array = state.actors.filter(func(actor): return actor.roof == roof and actor.count > 0)
	roof_actors.sort_custom(func(a, b): return a.x > b.x)
	for actor in roof_actors:
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
	var target = state.actor_at(next, -1, actor.roof, actor.id)
	if target != null:
		if target.side != actor.side:
			melee(state, actor, target)
		return
	#0x1bd6: steps into free or dynamite cells (0x1dce,1e22) wait while byte8548 is set.
	if state.sweep % 2 != 0:
		return
	var previous: int = actor.x
	actor.x = next
	_defuse(state, actor)
	#0x1c73: enemy plants when crossing wagons on player roof.
	if actor.side == 1 and actor.roof == 0 and next / 4 != previous / 4 and state.rnd(100) < state.aggressiveness:
		var slot := previous
		if state.trains[0][next / 4].class in state.Setup.VITAL_CLASSES:
			slot = next + delta
		if slot > 0 and slot < state.trains[0].size() * 4 and state.actor_at(slot, -1, 0) == null:
			state.charges.append({"side": 0, "slot": slot, "fuse": 5, "owner": 1})

static func _defuse(state, actor: Dictionary) -> void:
	#0x1db4: walking over opposing dynamite replaces its cell with the moving group.
	state.charges = state.charges.filter(func(charge): return not (charge.side == actor.roof and charge.slot == actor.x and charge.owner != actor.side))
