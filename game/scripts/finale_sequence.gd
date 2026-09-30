extends RefCounted

# MIT. IFEBO0x24d..346 waits; 0xa2..141 cloud counter and palette dispatch.
# Original 50Hz screen cadence: ALIS sys_sdl2.c k_frame_ticks=1000000/50.
const HZ := 50.0
const SHOTS := [[36, 30], [37, 5], [38, 5], [39, 5], [38, 5], [37, 3],
	[38, 2], [39, 20], [39, 5], [39, 20], [40, 20]]
const INTRO := 120
const LAST := INTRO + 241 # IFEBO0x131 tests counter >240.
var tick := 0
var remainder := 0.0
var seed_value := 0
var palettes: Array[int] = []


func start(seed_number: int) -> void:
	tick = 0
	remainder = 0.0
	seed_value = seed_number
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_number
	palettes.clear()
	var previous := 0
	for counter in 241:
		var chosen := rng.randi_range(0, 3) # IFEBO0xb4 rnd4.
		if chosen == previous:
			chosen = (chosen + 1) % 4 # 0xc8..d7 avoids repeated palette.
		palettes.append(chosen)
		previous = chosen


func advance(delta: float) -> bool:
	remainder += delta * HZ
	var nearest := roundi(remainder)
	var steps := nearest if is_equal_approx(remainder, float(nearest)) else floori(remainder)
	remainder = maxf(0.0, remainder - steps)
	tick = mini(LAST, tick + steps)
	return tick == LAST


func shot() -> int:
	var total := 0
	for item in SHOTS:
		total += item[1]
		if tick < total:
			return item[0]
	return 2 # IFEBO0x1e main composite, restored at counter200.


func clouds() -> PackedInt32Array:
	var moved := maxi(0, tick - INTRO - 35) # IFEBO0x10a..11a.
	return PackedInt32Array([-moved * 4, -moved * 3, -moved * 2, -moved])


func palette() -> int:
	var counter := tick - INTRO
	if counter < 0 or counter >= 200:
		return 0
	return palettes[counter]


func snapshot() -> Dictionary:
	return {"tick": tick, "remainder": remainder, "seed": seed_value}


static func valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in ["tick", "seed"]:
		if not (value.get(key) is int or value.get(key) is float) or not is_finite(value[key]) or value[key] != floor(value[key]):
			return false
	if value.tick < 0 or value.tick > LAST:
		return false
	return (value.get("remainder") is float or value.get("remainder") is int) and is_finite(value.remainder) and value.remainder >= 0 and value.remainder < 1


func restore(value: Dictionary) -> void:
	start(int(value.seed))
	tick = int(value.tick)
	remainder = value.remainder
