extends RefCounted

# MIT. TABLE4c5..5ee; TIME67e..961; YODA24c8..25ba,2732..2780,2984;
# TEXTEK171b..183a,1e35..1ff9. Presence is independent of other mover bits.
const Motion = preload("res://scripts/roamer_motion.gd")
const STARTS := [Vector2i(8,0),Vector2i(149,1),Vector2i(43,13),Vector2i(107,14),Vector2i(86,24),Vector2i(11,27),Vector2i(144,31),Vector2i(48,42),Vector2i(109,40),Vector2i(124,58),Vector2i(90,67)]
var herds: Array = [] # [dx,y,phase,heading,timer,quantity]
var nomad := [0,0,0,6,0] # x,y,phase,heading,callback
var initialized := false
var pending := ""
var herd_slot := -1
var commissioned := [0,0,0] # free mammoth space, slaves, soldiers
var caught := 0
var hunt_quantity := 0
var countdown := 0

func initialize(rng: RandomNumberGenerator, fauna) -> void:
	if initialized:
		return
	for index in 10:
		herds.append([rng.randi_range(0,129)-30,rng.randi_range(0,59)+5,0,rng.randi_range(1,9),rng.randi_range(0,39)+40,rng.randi_range(0,44)+5])
	fauna.initialize(rng)
	var chosen := rng.randi_range(0,10)
	while STARTS[chosen] == fauna.cell:
		chosen = rng.randi_range(0,10)
	_place_nomad(STARTS[chosen])
	initialized = true

func _place_nomad(cell: Vector2i) -> void:
	nomad = [cell.x,cell.y,0,6,0]

func nomad_cell() -> Vector2i:
	return Vector2i(nomad[0],nomad[1])

func herd_cell(index: int) -> Vector2i:
	return Vector2i(herds[index][0]+40,herds[index][1])

func has_presence(cell: Vector2i, bit: int) -> bool:
	if not initialized:
		return false
	if bit == 4:
		return nomad_cell() == cell
	if bit != 2:
		return false
	for index in herds.size():
		if herds[index][5] > 0 and herd_cell(index) == cell:
			return true
	return false

func advance(network, rng: RandomNumberGenerator, traps: Array = []) -> Array:
	var observations := []
	if not initialized:
		return observations
	for index in herds.size():
		var row: Array = herds[index]
		if row[5] <= 0:
			continue
		row[2] += 1
		if row[2] == 9:
			row[2] = 0
			var result: Dictionary = Motion.step(herd_cell(index),row[3],2,network)
			row[0] = result.cell.x-40
			row[1] = result.cell.y
			observations.append({"cell":result.cell,"code":index+40,"bit":2})
		row[4] -= 1
		var redirected := true
		if row[0] > 114:
			row[3] = rng.randi_range(0,2)*3+1
		elif row[0] < -35:
			row[3] = rng.randi_range(0,2)*3+3
		elif row[1] < 5:
			row[3] = rng.randi_range(1,3)
		elif row[1] > 66:
			row[3] = rng.randi_range(7,9)
		elif row[4] < 0:
			row[3] = rng.randi_range(1,9)
		else:
			redirected = false
		if redirected:
			row[4] = rng.randi_range(0,39)+30
	nomad[4] += 1
	if nomad[4] == 4:
		nomad[4] = 0
		nomad[2] += 1
		if nomad[2] == 3:
			nomad[2] = 0
			var result: Dictionary = Motion.step(nomad_cell(),nomad[3],4,network,traps)
			nomad[0] = result.cell.x
			nomad[1] = result.cell.y
			nomad[3] = result.heading
			observations.append({"cell":result.cell,"code":70,"bit":4})
		nomad[3] = Motion.turn(nomad_cell(),nomad[3],nomad[2],[],network,rng)
	return observations

func encounter(cell: Vector2i, network, rng: RandomNumberGenerator, bit := 0) -> String:
	if pending != "" or not initialized:
		return ""
	var code: int = network.tile(cell)
	var hunt_allowed: bool = bit != 4 and not ((code >= 38 and code <= 49) or code == 55)
	for index in herds.size():
		if hunt_allowed and herds[index][5] > 0 and herd_cell(index) == cell:
			herd_slot = index
			var row: Array = herds[index]
			row[0] = rng.randi_range(0,139)-30
			row[1] = rng.randi_range(0,59)+5
			row[3] = rng.randi_range(1,9)
			row[4] = rng.randi_range(0,39)+40
			pending = "herd_question"
			return pending
	if bit != 2 and has_presence(cell,4):
		pending = "nomad_question"
		return pending
	return ""

func answer(yes: bool, rng: RandomNumberGenerator, wagons) -> bool:
	if pending == "nomad_question":
		_place_nomad(STARTS[rng.randi_range(0,10)]) # relocation precedes either answer.
		pending = "nomad_trade" if yes else ""
		return true
	if pending != "herd_question":
		return false
	if not yes:
		pending = ""
		return true
	commissioned = [0,0,0]
	for row in wagons.wagons:
		if row[0] == 7:
			commissioned[0] += 3-row[3]
		elif row[0] in [5,6]:
			commissioned[1] += row[3]
		elif row[0] in [23,24]:
			commissioned[2] += row[3]
	pending = "hunt_commissioned"
	return true

func finish_hunt(wagons) -> bool:
	if pending != "hunt_commissioned":
		return false
	var divisor: int = 10-int((commissioned[1]+commissioned[2])/40)
	if divisor <= 1:
		divisor = 2
	hunt_quantity = herds[herd_slot][5]
	caught = mini(int(hunt_quantity/divisor)+1,commissioned[0])
	herds[herd_slot][5] -= caught
	var remaining := caught
	for row in wagons.wagons:
		if row[0] == 7 and remaining > 0:
			row[3] += remaining
			if row[3] > 3:
				remaining = row[3]-3
				row[3] = 3
			# Source1fb2 jumps past subtraction when <=3; preserve that behavior.
	countdown = 24 # TEXTEK1ff4.
	pending = "hunt_result"
	return true

func textek_tick() -> void:
	# TEXTEK45e6 calls45c8 only while positive; zero stops subsequent calls.
	if pending == "hunt_result" and countdown > 0:
		countdown -= 1

func close() -> void:
	pending = ""
	herd_slot = -1

func snapshot() -> Dictionary:
	return {"initialized":initialized,"herds":herds.duplicate(true),"nomad":nomad.duplicate(),"pending":pending,"herd_slot":herd_slot,"commissioned":commissioned.duplicate(),"caught":caught,"hunt_quantity":hunt_quantity,"countdown":countdown}

func restore(value: Variant) -> bool:
	if not value is Dictionary or not value.get("initialized") is bool or not value.get("herds") is Array or not value.get("nomad") is Array or not value.get("commissioned") is Array:
		return false
	if value.herds.size() != (10 if value.initialized else 0) or value.nomad.size() != 5 or value.commissioned.size() != 3 or value.get("pending") not in ["","nomad_question","nomad_trade","herd_question","hunt_commissioned","hunt_result"]:
		return false
	var rows: Array = value.herds.duplicate(true)
	for row in rows:
		if not row is Array or row.size() != 6:
			return false
	for row in rows+[value.nomad,value.commissioned,[value.get("herd_slot"),value.get("caught"),value.get("hunt_quantity"),value.get("countdown")]]:
		for item in row:
			if not (item is int or item is float) or not is_finite(item) or item != floor(item) or item < -32768 or item > 32767:
				return false
	for row in rows:
		if row[2] < 0 or row[2] > 8 or row[3] < 1 or row[3] > 9 or row[5] < 0 or row[5] > 49:
			return false
	if value.nomad[2] < 0 or value.nomad[2] > 2 or value.nomad[3] < 1 or value.nomad[3] > 9 or value.nomad[4] < 0 or value.nomad[4] > 3 or value.herd_slot < -1 or value.herd_slot > 9:
		return false
	if value.pending.begins_with("hunt") or value.pending == "herd_question":
		if value.herd_slot < 0:
			return false
	for row in rows:
		for index in row.size():
			row[index] = int(row[index])
	if value.countdown < 0 or value.countdown > 24 or value.caught < 0 or value.caught > 49 or value.hunt_quantity < 0 or value.hunt_quantity > 49:
		return false
	for item in value.commissioned:
		if item < 0:
			return false
	herds = rows
	nomad = value.nomad.map(func(item): return int(item))
	commissioned = value.commissioned.map(func(item): return int(item))
	initialized = value.initialized
	pending = value.pending
	herd_slot = int(value.herd_slot)
	caught = int(value.caught)
	hunt_quantity = int(value.hunt_quantity)
	countdown = int(value.countdown)
	return true
