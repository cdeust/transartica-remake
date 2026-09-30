extends RefCounted

# MIT. TABLE0x282..39e traps, TABLE0x463..4b7 mole cells, TIME0xdb0..f76 cars.
const TRAPS := [Vector2i(24, 4), Vector2i(26, 2), Vector2i(27, 6), Vector2i(33, 7), Vector2i(38, 4), Vector2i(24, 7), Vector2i(33, 1)]
const MOLES := [Vector2i(50, 44), Vector2i(74, 38), Vector2i(92, 57), Vector2i(83, 27), Vector2i(44, 59), Vector2i(5, 28), Vector2i(66, 40)]
var traps: Array = [-1, -1, -1, -1, -1, -1, -1]
var mole_times: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] # TABLE0xc4 clears, index x%10.


func intercept_trap(cell: Vector2i, network) -> bool:
	var trap := TRAPS.find(cell)
	if trap >= 0 and traps[trap] == -1:
		traps[trap] = 0
		network.set_campaign_tile(cell, -absi(network.tile(cell))) # TIME0xdf0.
		return true
	return false


func intercept_mole(cell: Vector2i, missile: bool, context: Dictionary) -> bool:
	if cell not in MOLES:
		return false
	var hit: bool = context.rng.randi_range(0, 5) == 0 # TIME0xf2f exact rnd6.
	mole_times[cell.x % 10] = -1 if hit and not missile else context.calendar.day * 50 + context.calendar.hour
	return hit


func snapshot() -> Dictionary:
	return {"traps": traps.duplicate(), "mole_times": mole_times.duplicate()}


func restore(value: Variant) -> bool:
	if not value is Dictionary or not value.get("traps") is Array or value.traps.size() != TRAPS.size() or not value.get("mole_times") is Array or value.mole_times.size() != 10:
		return false
	var parsed: Array = []
	for item in value.traps + value.mole_times:
		if not (item is int or item is float) or not is_finite(item) or item != floor(item):
			return false
		parsed.append(int(item))
	for index in TRAPS.size():
		if parsed[index] not in [-1, 0]:
			return false
	traps = parsed.slice(0, TRAPS.size())
	mole_times = parsed.slice(TRAPS.size())
	return true
