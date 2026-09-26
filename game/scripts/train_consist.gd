extends RefCounted

# Authored visual lengths in map cells: east anchor spans in assets/travel/vehicles.json
# divided by the locomotive's (486.2 texels = 1 cell), rounded to 0.01.
# These are not historical masses or capacity rules.
const LENGTHS := {"locomotive": 1.0, "tender": 0.75, "sleeper": 0.77, "boxcar": 0.78, "observation": 0.88, "armored": 0.8}
var vehicles: Array[String] = ["locomotive", "tender", "sleeper", "boxcar", "observation", "armored"]


func snapshot() -> Array:
	return vehicles.duplicate()


func restore(value: Variant) -> bool:
	if not value is Array or value.is_empty() or value[0] != "locomotive":
		return false
	for kind in value:
		if not kind is String or not LENGTHS.has(kind):
			return false
	vehicles.assign(value)
	return true


func length_world() -> float:
	var total := 0.0
	for kind in vehicles:
		total += LENGTHS[kind]
	return total
