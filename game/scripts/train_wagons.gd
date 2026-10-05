extends RefCounted

# Rules-level wagon table main[0x2e1a]: up to 100 entries of [type, state, goods, quantity]
# (tasks/evidence/city-scripts.md §4). Distinct from train_consist.gd, whose vehicle list is
# the rendered train; the mapping from these types to drawn vehicles is not decoded.
const MAX_WAGONS := 100
const TYPE := 0
const STATE := 1
const GOODS := 2
const QUANTITY := 3
# TABLE 0x699..0x6f4: initial types, only the last entry carries a load of 10.
const INITIAL := [[1, 0, 0, 0], [21, 0, 0, 0], [2, 0, 0, 0], [3, 0, 0, 0], [17, 0, 0, 0], [23, 0, 0, 10]]
# TIME 0x2a77: base weight of wagon types 1..25.
const BASE_WEIGHT := [1000, 50, 40, 110, 65, 85, 60, 105, 20, 100, 100, 40, 120, 40, 45, 55, 45, 55, 40, 90, 50, 50, 80, 100, 200]

var wagons: Array = []


func _init() -> void:
	reset()


func reset() -> void:
	wagons = INITIAL.duplicate(true)


func count() -> int:
	return wagons.size()


# TIME 0x2a77 base weight plus the 0x2b4a load term, summed over the wagons.
func mass() -> int:
	var total := 0
	for wagon in wagons:
		total += BASE_WEIGHT[wagon[TYPE] - 1] + _load_weight(wagon[TYPE], wagon[QUANTITY])
	return total


func _load_weight(kind: int, quantity: int) -> int:
	match kind:
		5, 6, 23, 24: return quantity / 10
		7, 21: return quantity * 10
		14, 15, 17, 18, 19: return quantity
	return 0


func snapshot() -> Array:
	return wagons.duplicate(true)


func restore(value: Variant) -> bool:
	if not value is Array or value.is_empty() or value.size() > MAX_WAGONS:
		return false
	var parsed: Array = []
	for entry in value:
		if not entry is Array or entry.size() != 4:
			return false
		var wagon: Array = []
		for field in entry:
			if not (typeof(field) == TYPE_INT or typeof(field) == TYPE_FLOAT) or float(field) != floor(float(field)):
				return false
			wagon.append(int(field))
		# Signed byte fields of main[0x2e1a]; ranges from §4 of the city-scripts evidence.
		# WDECOR5ec7..5ece signed survivor correction can underflow crew stocks.
		var minimum_quantity := -128 if wagon[TYPE] in [23,24] else 0
		if wagon[TYPE] < 1 or wagon[TYPE] > 25 or wagon[STATE] < 0 or wagon[STATE] > 3 \
				or wagon[GOODS] < 0 or wagon[GOODS] > 16 or wagon[QUANTITY] < minimum_quantity or wagon[QUANTITY] > 127:
			return false
		parsed.append(wagon)
	wagons = parsed
	return true
