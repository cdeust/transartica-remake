extends RefCounted
# MIT. Save boundary validation; constraints derive from WDECOR arrays/actions.

static func integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(value) and value == floor(value) and value >= low and value <= high

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 1:
		return false
	for key in ["seed", "state"]:
		if not data.get(key) is String or not data[key].is_valid_int() or str(int(data[key])) != data[key]:
			return false
	for key in ["trains", "offsets", "velocities", "actors", "charges", "original"]:
		if not data.get(key) is Array:
			return false
	if data.trains.size() != 2 or data.offsets.size() != 2 or data.velocities.size() != 2:
		return false
	for side in 2:
		if not data.trains[side] is Array or data.trains[side].is_empty() or data.trains[side].size() > 101:
			return false
		for car in data.trains[side]:
			if not _car(car):
				return false
		if not integer(data.offsets[side], -100000, 100000) or not integer(data.velocities[side], -1, 1):
			return false
	var bounds := {"columns": [80,416], "scan": [0,2911], "scan_side": [0,1], "sweep": [0,2147483647], "ai_wagon": [0,data.trains[1].size()-1], "ai_wait": [0,119], "ai_direction": [-1,1], "ticks": [0,2147483647], "next_id": [0,2147483647], "outcome": [0,2], "aggressiveness": [0,99]}
	for key in bounds:
		if not integer(data.get(key), bounds[key][0], bounds[key][1]):
			return false
	# Optional for legacy saves; WDECOR4c32..4c68 bounds minus center0203.
	var camera_limit: int = data.columns * 16 / 2 - 160
	if data.has("camera_offset") and not integer(data.camera_offset, -camera_limit, camera_limit):
		return false
	if data.scan >= data.columns * 7 or not data.get("settled") is bool:
		return false
	if not (data.get("remainder") is float or data.get("remainder") is int) or not is_finite(data.remainder) or absf(data.remainder) > 1:
		return false
	if not data.get("initial_pools") is Dictionary:
		return false
	for key in ["soldiers", "mammoths", "guns"]:
		# Source: at most100 signed crew bytes, each at least-128.
		var minimum := -128*preload("res://scripts/train_wagons.gd").MAX_WAGONS if key == "soldiers" else 0
		if not integer(data.initial_pools.get(key), minimum, 100000):
			return false
	if not _entities(data): return false
	if data.has("survivors") != data.has("army_strength"): return false
	var army = data.get("army_strength",preload("res://scripts/tactical_survivors.gd").army(data))
	# Source: ALIS alocw/xadd16 persistent signed-word counters.
	if not army is Array or army.size() != 2 or not integer(army[0],-32768,32767) or not integer(army[1],-32768,32767): return false
	var survivors = data.get("survivors",preload("res://scripts/tactical_survivors.gd").legacy(data))
	return survivors is Dictionary and integer(survivors.get("soldiers"),-32768,int(data.initial_pools.soldiers)) and integer(survivors.get("mammoths"),0,int(data.initial_pools.mammoths))

static func _entities(data: Dictionary) -> bool:
	var seen := {}
	for actor in data.actors:
		if not _actor(actor, data) or seen.has(int(actor.id)):
			return false
		seen[int(actor.id)] = true
	for charge in data.charges:
		if not charge is Dictionary or not integer(charge.get("side"),0,1) or not integer(charge.get("owner"),0,1) or not integer(charge.get("fuse"),1,5):
			return false
		if not integer(charge.get("slot"),1,data.trains[int(charge.side)].size()*4-1):
			return false
	return _original(data.original)

static func _car(car: Variant) -> bool:
	return car is Dictionary and integer(car.get("class"),1,25) and integer(car.get("health"),0,3) and integer(car.get("quantity"),-128 if car.get("class") == 1 else 0,100000) and integer(car.get("reload"),0,23)

static func _actor(actor: Variant, data: Dictionary) -> bool:
	if not actor is Dictionary or not actor.get("mammoth") is bool:
		return false
	for key in ["id", "count", "x", "y", "roof", "side", "direction", "processed"]:
		if not integer(actor.get(key),-1,2147483647):
			return false
	if actor.id < 0 or actor.id >= data.next_id or actor.count <= 0 or actor.count > 31 or actor.side < 0 or actor.side > 1 or actor.roof > 1 or actor.direction < 0 or actor.direction > 8:
		return false
	if actor.roof >= 0:
		return actor.y == -1 and actor.x >= 0 and actor.x < data.trains[int(actor.roof)].size()*4
	var span := 2 if actor.mammoth else 1
	return actor.x >= 0 and actor.x + span <= data.columns and actor.y >= 0 and actor.y + span <= 7

static func _original(wagons: Array) -> bool:
	if wagons.is_empty() or wagons.size() > 100:
		return false
	for car in wagons:
		if not car is Array or car.size() != 4:
			return false
		if not integer(car[0],1,25) or not integer(car[1],0,3) or not integer(car[2],0,25) or not integer(car[3],-128 if int(car[0]) in [23,24] else 0,100000):
			return false
	return true

static func normalize(value: Variant) -> Variant:
	if value is float:
		return int(value)
	if value is Array:
		var result: Array=[]
		for child in value: result.append(normalize(child))
		return result
	if value is Dictionary:
		var result: Dictionary={}
		for key in value: result[key]=normalize(value[key])
		return result
	return value
