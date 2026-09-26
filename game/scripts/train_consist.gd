extends RefCounted

# Authored visual lengths in map cells: alpha-span heights in
# assets/travel/vehicles-overhead.json (tools/build_overhead_manifest.py)
# divided by the locomotive's (506px = 1 cell), rounded to 0.01. These are not
# historical masses or capacity rules. The near-uniform ratios (0.95-1.0) are
# what the accepted overhead prototype actually draws, not the differentiated
# lengths its generation prompt requested (see build_overhead_manifest.py
# docstring and tasks/todo.md) -- flagged there as art still to redo.
const LENGTHS := {"locomotive": 1.0, "tender": 0.99, "sleeper": 1.0, "boxcar": 0.95, "observation": 0.96, "armored": 0.96}

# Wagon-type -> drawn-vehicle mapping. This is a REMAKE ARTISTIC CHOICE, not a
# decoded rule: the original game draws one sprite per wagon type (25 of
# them, reference-private/commerce.json "wagon_names"), and only six overhead
# drawings exist today. The pairing follows the ORDER of the initial
# composition table (train_wagons.gd INITIAL types [1,21,2,3,17,23]) against
# the pre-existing default drawn-vehicle order (locomotive, tender, sleeper,
# boxcar, observation, armored) -- a positional correspondence, not a
# thematic decode of what a "general quarters" or "merchandise" wagon should
# look like. The other 19 types have no entry: derive_from_wagons() leaves
# them undrawn rather than substitute an invented sprite (tasks/todo.md,
# "Dessiner les 19 autres types").
const TYPE_TO_KIND := {
	1: "locomotive", # LOCOMOTIVE
	21: "tender", # TENDER
	2: "sleeper", # GENERAL QUARTERS
	3: "boxcar", # BOUDOIR
	17: "observation", # MERCHANDISE
	23: "armored", # BARRACKS
}

var vehicles: Array[String] = ["locomotive", "tender", "sleeper", "boxcar", "observation", "armored"]


# Precondition: wagon_table exposes `wagons` (Array of [type, state, goods,
# quantity], train_wagons.gd's TYPE index) and is never null.
# Postcondition: vehicles holds one entry per wagon whose type is in
# TYPE_TO_KIND, same relative order as wagon_table.wagons; wagons of an
# unmapped type contribute nothing (not a placeholder, not a fabricated
# generic sprite). Composition is therefore always a pure function of
# wagon_table; there is no independent state to fall out of sync with it.
func derive_from_wagons(wagon_table) -> void:
	var derived: Array[String] = []
	for wagon in wagon_table.wagons:
		var kind: Variant = TYPE_TO_KIND.get(wagon[wagon_table.TYPE])
		if kind != null:
			derived.append(kind)
	vehicles = derived


func snapshot() -> Array:
	return vehicles.duplicate()


func length_world() -> float:
	var total := 0.0
	for kind in vehicles:
		total += LENGTHS[kind]
	return total
