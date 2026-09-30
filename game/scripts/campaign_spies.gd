extends RefCounted

# MIT. Spy record/effects: MAIN0x3b, CARTE0x1dc9 and0x27a4, TIME0x976.
const W = preload("res://scripts/train_wagons.gd")
const SPY_COUNT := 20 # TIME0xc85 slots0..19.
const SPY_FIELDS := 15 # MAIN0x3b record stride15; TIME0x216d field14.
var spies: Array = []
var central_destroyed := false # CARTE0x28cc main6515.


# Commerce's simplified slot list remains synchronized; only new aboard recruits
# overwrite a free record. Travelling/posted records retain their complete state.
func sync_recruits(trade) -> void:
	for index in SPY_COUNT:
		if trade.spy_slots[index] == 1 and spies[index][0] == 0:
			spies[index][0] = 1
		elif trade.spy_slots[index] == 0 and spies[index][0] == 1:
			spies[index].fill(0)
		trade.spy_slots[index] = spies[index][0]


func send_spy(destination: Vector2i, player: Vector2i, wagons, trade) -> int:
	sync_recruits(trade)
	if not _in_bounds(destination):
		return -1
	for index in SPY_COUNT:
		if spies[index][0] != 1:
			continue
		spies[index][0] = 2 # CARTE0x1de0.
		spies[index][1] = player.x - 40
		spies[index][2] = player.y
		spies[index][3] = destination.x - 40
		spies[index][4] = destination.y
		_consume(wagons, 0, 22)
		trade.spy_slots[index] = 2
		return index
	return -1


# TIME0x976 increments travel phase each call; every third call moves one cell,
# straight over terrain towards destination (numeric-keypad heading0x9e9..ac1).
func advance_spies(network, trade, stoup) -> Array:
	var arrived: Array = []
	for index in SPY_COUNT:
		var record: Array = spies[index]
		if record[0] != 2:
			continue
		record[5] += 1
		if record[5] != 3:
			continue
		record[5] = 0
		record[1] += signi(record[3] - record[1])
		record[2] += signi(record[4] - record[2])
		if record[1] != record[3] or record[2] != record[4]:
			continue
		record[0] = 3
		record[6] = 5
		trade.spy_slots[index] = 3
		var cell := Vector2i(record[1] + 40, record[2])
		arrived.append(index)
		if absi(record[1] - 25) < 2 and absi(record[2] - 20) < 2:
			network.set_campaign_tile(cell, -124)
			network.set_campaign_tile(cell + Vector2i.LEFT, -124)
			stoup.push(127) # TIME0xbc9..c64 central discovery.
	return arrived


# CARTE0x27ae refuses travelling or already-used spy; confirmed action33 adds100
# to field13 before tile dispatch. Central sabotage never requires Urga's key.
func posted_at(cell: Vector2i) -> int:
	for index in SPY_COUNT:
		var record: Array = spies[index]
		if record[0] == 3 and Vector2i(record[1] + 40, record[2]) == cell:
			return index
	return -1


func retrieve_spy(index: int, accept: bool, trade) -> bool:
	if index < 0 or index >= SPY_COUNT or spies[index][0] != 3:
		return false
	if accept:
		spies[index].fill(0)
		spies[index][0] = 1 # YODA0x26e1..270d resets fields1..14, no load increment.
		trade.spy_slots[index] = 1
	else:
		spies[index][13] %= 100 # YODA0x2713.
	return true


func observe_enemy(slot: int, cell: Vector2i, calendar, stoup) -> void:
	var index := posted_at(cell)
	if index < 0:
		return
	var record: Array = spies[index]
	stoup.push(index + 101) # TIME0x20bb.
	record[8] = record[7]
	record[7] = slot + 1
	record[12] = record[9]
	record[9] = calendar.day
	record[13] = record[10]
	record[10] = calendar.hour
	record[14] = record[11]
	record[11] = calendar.minute


func sabotage(index: int, network, stoup) -> Dictionary:
	if index < 0 or index >= SPY_COUNT:
		return {}
	var record: Array = spies[index]
	if record[0] != 3 or record[13] > 99:
		return {}
	record[13] += 100
	var cell := Vector2i(record[1] + 40, record[2])
	var code: int = network.tile(cell)
	if code == -124:
		central_destroyed = true
		stoup.push(125)
	else:
		var changes := {63: 67, 64: 69, -117: 114, -121: -116}
		if changes.has(code):
			network.set_campaign_tile(cell, changes[code])
		elif code > 1 and code < 59 and (code < 34 or code > 37):
			network.set_campaign_tile(cell, -code)
	return {"central": central_destroyed, "cell": [cell.x, cell.y]}


func _consume(wagons, goods: int, kind := 0) -> bool:
	for wagon in wagons.wagons:
		if (wagon[W.TYPE] == kind if kind != 0 else wagon[W.GOODS] == goods) and wagon[W.QUANTITY] > 0:
			wagon[W.QUANTITY] -= 1
			if kind == 0 and wagon[W.QUANTITY] == 0:
				wagon[W.GOODS] = 0
			return true
	return false


static func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < 160 and cell.y >= 0 and cell.y < 73 # FORMAT-CARTE.
