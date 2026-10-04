extends RefCounted

# MIT. TEXTEK0xfbe..12df; ALIS adirw/amainw and sdirw store signed words.
# This helper preserves source overflow and negative free-capacity behavior.
static func word(value: int) -> int:
	return ((value + 32768) & 65535) - 32768

static func resources(wagons: Array) -> Dictionary:
	var result := {"slaves":0,"mammoths":0,"cranes":0}
	for wagon in wagons:
		if wagon[0] in [5,6]:
			result.slaves = word(result.slaves + int(wagon[3]))
		elif wagon[0] == 7:
			result.mammoths = word(result.mammoths + int(wagon[3]))
		elif wagon[0] == 16 and wagon[1] < 3:
			result.cranes += 1
	return result

static func calculate(wagons: Array, crew: Dictionary, wealth: int, lignite: int, anthracite: int) -> int:
	var capacity := 0
	for wagon in wagons:
		if wagon[0] == 21 and wagon[1] != 3:
			capacity = word(capacity + 5000)
	if capacity < 0:
		capacity = 32000
	var free := word(capacity - (anthracite + lignite))
	var work := word(int(crew.slaves) + int(crew.mammoths) * 30)
	if crew.cranes != 0:
		work = word(work + 150)
	var quantity := word((maxi(wealth,0) + 1) * (int(work / 5) + 1))
	if quantity < 0:
		quantity = 30000
	return mini(quantity,free)

static func credited_total(before: int, quantity: int) -> int:
	var total := word(before + quantity)
	return 31000 if total < 0 or total > 31000 else total

static func valid_resources(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 3:
		return false
	for key in ["slaves","mammoths","cranes"]:
		if not integer(value.get(key),-32768,32767):
			return false
	return value.cranes >= 0

static func integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(value) and value >= low and value <= high
