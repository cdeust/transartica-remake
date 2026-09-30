extends RefCounted

# MIT. TIME0xc91..1126 and CARTE0x1295..159e; finite original100-cycle run.
const W = preload("res://scripts/train_wagons.gd")
const Network = preload("res://scripts/rail_network.gd")
const CYCLES := 100 # TIME0xfdb.
const OBSTACLES := [34, 35, 36, 37, 65, 67, 69, 78, 79, 114, -116, -120]


static func launch(player: Vector2i, player_heading: int, phase: int, heading: int,
		missile: bool, wagons, network, enemies = null) -> Dictionary:
	if heading not in [2, 4, 6, 8]:
		return {}
	var cell := player
	var moving_heading := player_heading
	var moving_phase := phase
	var reverses := (heading == 2 and player_heading == 8) or (heading == 8 and player_heading == 2) \
		or (heading == 6 and player_heading in [4, 1, 7]) or (heading == 4 and player_heading in [3, 6, 9])
	if reverses:
		moving_heading = 10 - moving_heading
		moving_phase = absi(phase - 2) - 1 # TIME0x1190.
	var met := false
	var path: Array = []
	for cycle in CYCLES:
		moving_phase += 1
		if moving_phase == 3:
			moving_phase = 0
			cell += Network.DELTAS[moving_heading]
			# TIME0x1a25 movement shared by car and train; dimensions in FORMAT-CARTE.
			cell.x = posmod(cell.x, Network.WIDTH)
			cell.y = posmod(cell.y, Network.HEIGHT)
			path.append([cell.x, cell.y])
			if cell == player:
				met = true
				break
			if enemies != null:
				var slot: int = enemies.encounter_at(cell)
				if slot >= 0:
					if missile and slot != 29: # TIME0xe5c Minotaur protected.
						var record: Array = enemies.slots[slot]
						record[0] = 5 * signi(record[0])
						record[7] -= (record[7] % 100) / 3
					met = true
					break
			var code: int = network.tile(cell)
			if code in OBSTACLES or (code < 0 and code > -108):
				met = true
				break
		moving_heading = network.turn(cell, moving_heading)
	_consume(wagons, 3)
	if missile:
		_consume(wagons, 2)
	return {"message": 10 if met else 11, "cell": [cell.x, cell.y], "path": path,
		"obstacle": met, "missile": missile}


static func _consume(wagons, goods: int) -> void:
	for wagon in wagons.wagons:
		if wagon[W.GOODS] == goods and wagon[W.QUANTITY] > 0:
			wagon[W.QUANTITY] -= 1
			if wagon[W.QUANTITY] == 0:
				wagon[W.GOODS] = 0
			return
