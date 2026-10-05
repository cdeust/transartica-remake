extends RefCounted
# MIT. WDECOR0x0deb train movement,0x0f49 AI,0x17b4/5001 weapons.
const Setup = preload("res://scripts/combat_setup.gd")
const Survivors = preload("res://scripts/tactical_survivors.gd")

static func move_trains(state) -> void:
	for side in 2:
		if state.trains[side][0].health <= 0:
			state.velocities[side] = 0
		state.offsets[side] = clampi(state.offsets[side] + state.velocities[side], state.trains[side].size() * 64 - 320 - state.center_offset(), state.columns * 16 - 320 - state.center_offset())
	if state.ai_wait > 0:
		state.ai_wait -= 1
	else:
		state.ai_wait = state.rnd(100) + 20
		var enemy: int = state.offsets[1]
		var player: int = state.offsets[0]
		if enemy - (state.trains[1].size() / 2) * 64 > player or enemy < player - (state.trains[0].size() / 2) * 64:
			state.ai_direction = signi(player - enemy)
		elif state.rnd(3) != 0:
			if enemy - state.trains[1].size() * 64 < state.columns * 16 / 3:
				state.ai_direction = 1
			elif enemy > state.columns * 16 * 2 / 3:
				state.ai_direction = -1
			else:
				state.ai_direction = state.rnd(3) - 1
		else:
			state.ai_direction = state.rnd(3) - 1
	if state.trains[1][0].health > 0:
		state.velocities[1] += signi(state.ai_direction - state.velocities[1])

static func enemy_ai(state) -> void:
	var index: int = state.ai_wagon
	state.ai_wagon = (index + 1) % state.trains[1].size() #0x0ef1 one wagon per tick.
	var car: Dictionary = state.trains[1][index]
	if car.health <= 0:
		return
	match car.class:
		Setup.BARRACKS:
			if state.rnd(80) < state.aggressiveness:
				state.deploy(1, index, state.rnd(30) + 1)
		Setup.LIVESTOCK:
			if state.rnd(800) < state.aggressiveness:
				state.deploy(1, index, mini(state.rnd(62) + 1, 31))
		Setup.CANNON:
			if state.rnd(800) < state.aggressiveness and car.reload == 0:
				car.reload = 23
		Setup.MACHINE_GUN:
			if state.rnd(100) < state.aggressiveness and car.reload == 0:
				car.reload = 13
				if state.rnd(100) < state.aggressiveness:
					var x: int = state.train_cell(1, index)
					var last: int = 6 - state.rnd(2)
					for y in range(last + 1):
						var actor = state.actor_at(x, y)
						if actor != null and actor.side == 1:
							car.reload = 0
							break

static func run(state) -> void:
	#0x17b4: every enemy weapon;0x5001: only six visible player slots.
	#4fca/4feb: visibility follows camera scrolling, not a fixed world band.
	var first_player_slot: int = (state.offsets[0] - state.camera_offset) / 64
	for side in [1, 0]:
		for index in state.trains[side].size():
			var car: Dictionary = state.trains[side][index]
			if car.health <= 0 or car.reload <= 0:
				continue
			if side == 0:
				if index < first_player_slot or index > first_player_slot + 5: #5420.
					continue
			var reload: int = car.reload
			# WDECOR51eb/5640: machine-gun sound at12;52df/5715 cannon at23.
			if car.class == Setup.MACHINE_GUN and reload == 12:
				state.audio_cue_requested.emit(0x60ab if side == 0 else 0x60b7)
			elif car.class == Setup.CANNON and reload == 23:
				state.presentation_event_requested.emit({"kind":"cannon","side":side,"wagon":index})
				state.audio_cue_requested.emit(0x60c3 if side == 0 else 0x60cf)
			car.reload -= 1
			if car.class == Setup.CANNON and reload == 22:
				_cannon(state, side, index)
			elif car.class == Setup.MACHINE_GUN and reload % 2 == 0:
				_machine_gun(state, side, index)

static func _cannon(state, side: int, index: int) -> void:
	var opposite := 1 - side
	var relative: int = state.offsets[opposite] + 32 - state.offsets[side] + index * 64
	if relative < 0 or relative >= state.trains[opposite].size() * 64:
		return
	var target := relative / 64
	var car: Dictionary = state.trains[opposite][target]
	if car.health > 0:
		state.audio_cue_requested.emit(0x60db) # WDECOR5373/5791 cannon impact.
		car.health -= 1
		state.events.append({"kind": "impact", "side": opposite, "wagon": target})
		#0x18f7–1959: locomotive companion mirrors the lower health.
		if opposite == 0 and car.class in [Setup.LOCOMOTIVE, Setup.LOCOMOTIVE_COMPANION]:
			for linked in state.trains[0]:
				if linked.class in [Setup.LOCOMOTIVE, Setup.LOCOMOTIVE_COMPANION]:
					linked.health = mini(linked.health, car.health)
		if car.health <= 0:
			destroy(state, opposite, target)

static func _machine_gun(state, side: int, index: int) -> void:
	# Every source burst has a tracer, including shots that miss an actor.
	state.presentation_event_requested.emit({"kind":"machinegun","side":side,"wagon":index})
	var column: int = state.train_cell(side, index)
	#0x5249 random reach for player's gun, entire column for enemy0x183d.
	var last: int = state.rnd(4) if side == 0 else 6
	var rows := range(6, last - 1, -1) if side == 0 else range(7)
	for row in rows:
		var target = state.actor_at(column, row)
		if target == null:
			continue
		var before_count: int = target.count
		if target.mammoth:
			if state.rnd(3) != 0:
				target.count = maxi(0, target.count - state.rnd(3))
		else:
			target.count = maxi(0, target.count - state.rnd(10 if target.side == 0 else 7) - 1)
		Survivors.damage_actor(state,target,before_count) # WDECOR0x0d90..0x0dc7.
		state.events.append({"kind": "shot", "x": target.x, "y": target.y})
		return #0x5258/1843 first occupied cell, friendly fire preserved.

static func destroy(state, side: int, index: int) -> void:
	state.audio_cue_requested.emit(0x60f5) # WDECORccb→60e7 wagon destruction.
	var car: Dictionary = state.trains[side][index]
	#0x0ae4/0b25/0c10/0c4b: engine halves and enemy tender clear their partner.
	var linked := -1
	if car.class == Setup.LOCOMOTIVE and index + 1 < state.trains[side].size():
		linked = index + 1
	elif car.class == Setup.LOCOMOTIVE_COMPANION and index > 0:
		linked = index - 1
	elif side == 1 and car.class == Setup.TENDER and index > 0:
		linked = index - 1 #0x0c4b..0c82: enemy coal wagon disables its engine.
	if linked >= 0:
		Survivors.destroy_wagon(state,state.trains[side][linked],side)
		state.trains[side][linked].health = 0
		state.trains[side][linked].quantity = 0
		state.trains[side][linked].reload = 0
		for actor in state.actors:
			if actor.roof == side and actor.x / 4 == linked:
				var before_count: int = actor.count
				actor.count = 0
				Survivors.damage_actor(state,actor,before_count) #0x0d01..0x0d16.
	Survivors.destroy_wagon(state,car,side)
	car.health = 0
	car.quantity = 0
	car.reload = 0
	for actor in state.actors:
		if actor.roof == side and actor.x / 4 == index:
			var before_count: int = actor.count
			actor.count = 0
			Survivors.damage_actor(state,actor,before_count) #0x0d01..0x0d16.
	state.events.append({"kind": "destroy", "side": side, "wagon": index})
