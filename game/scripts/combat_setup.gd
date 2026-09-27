extends RefCounted

# Train combat setup: wdecor.alis (train-combat script id 33), verified against
# reference-private/observations/combat-20260927/wdecor.txt (offsets below are
# byte offsets in the unpacked script, regenerated with tools/claude/xdisasm.py
# and printed with tools/claude/alis_pretty.py). Specification: tasks/evidence/combat.md.
# Correction to combat.md §4: the "class" numbers cited there ("locomotive 5",
# "GQ 22", "boudoir 23", "barracks/XL 1", "cannon 2", "machine gun 3",
# "livestock 4", "tender 8", "merchandise 6") are wdecor's own internal per-wagon
# combat "class" ids, NOT main[0x2e1a] wagon TYPE ids. The type -> class table is
# the cswitch1 at wdecor 0x0440 (25 cases, one per type 1..25): confirmed exactly
# once, so TYPE_TO_CLASS below is the source of truth for the mapping.
const Wagons = preload("res://scripts/train_wagons.gd")

# wdecor 0x0440-0x0592: main[0x2e1a][i][0] (type, 1-based) -> combat class.
const TYPE_TO_CLASS := [
	5, 22, 23, 14, 10, 9, 4, 19, 18, 15, 2, 3, 20, 13, 11, 17, 6, 6, 12, 21, 8, 16, 1, 1, 7,
]

const BARRACKS := 1
const CANNON := 2
const MACHINE_GUN := 3
const LIVESTOCK := 4
const LOCOMOTIVE := 5
const MERCHANDISE := 6
const WRECK := 7 # wdecor 0x058c/0x05fc: scrapped wagons (any type) become this class.
const TENDER := 8
const GQ := 22
const BOUDOIR := 23
const LOCOMOTIVE_COMPANION := 25 # wdecor 0x0614-0x0652: synthetic second slot after the locomotive.

# wdecor 0x0170/0x0ab6: vital-flag classes. Losing any of them clears slocb[8374].
const VITAL_CLASSES := [LOCOMOTIVE, GQ, BOUDOIR]

# Wagon TYPE ids used directly (not through TYPE_TO_CLASS) by textek's
# auto-resolve (0x49fc), which switches on main[0x2e1a][i][0] itself.
const TYPE_LOCOMOTIVE := 1
const TYPE_PRISON := 5
const TYPE_ALCATRAZ := 6
const TYPE_LIVESTOCK := 7
const TYPE_TENDER := 21
const TYPE_CANNON := 11
const TYPE_MACHINE_GUN := 12
const TYPE_MERCHANDISE := 17
const TYPE_XL_MERCHANDISE := 18
const TYPE_SPY := 22
const TYPE_BARRACKS := 23
const TYPE_XL_BARRACKS := 24


# ornd (opernames.c:433): 0..n-1, 0 when n<=0. Same semantics as city_trade.gd::_rnd.
static func _rnd(rng: RandomNumberGenerator, n: int) -> int:
	return rng.randi_range(0, n - 1) if n > 0 else 0


# wdecor 0x0440-0x0652: the player's fighting roster derived from main[0x2e1a].
# Precondition: wagons.wagons entries are [type 1..25, state 0..3, goods, quantity].
# Postcondition: one entry per wagon (class, quantity, health), plus one extra
# LOCOMOTIVE_COMPANION entry (health fixed 3, quantity 0) immediately after an
# intact locomotive (0x0614-0x0652: skipped when the locomotive's own health is 0,
# because the health-zero override at 0x05ec runs before the class==5 test at 0x0607).
static func player_roster(wagons) -> Array:
	var roster: Array = []
	for wagon in wagons.wagons:
		var wagon_type: int = wagon[Wagons.TYPE]
		var health: int = 3 - wagon[Wagons.STATE] # wdecor 0x05b2
		var wagon_class: int = TYPE_TO_CLASS[wagon_type - 1]
		var quantity: int = wagon[Wagons.QUANTITY]
		if wagon_class == CANNON or wagon_class == MACHINE_GUN: # wdecor 0x05cb-0x05e1
			quantity = 0
		var is_locomotive := wagon_class == LOCOMOTIVE
		if health == 0: # wdecor 0x05ec-0x05fc
			wagon_class = WRECK
		roster.append({"class": wagon_class, "quantity": quantity, "health": health})
		if is_locomotive and health > 0: # wdecor 0x0607-0x0652
			roster.append({"class": LOCOMOTIVE_COMPANION, "quantity": 0, "health": 3})
	return roster


# wdecor 0x0172/0x0ab6: true while every vital wagon (locomotive, GQ, boudoir)
# has health > 0. The evidence's "vital flag 8374" starts true and is cleared,
# never set again, so this is computed fresh each call rather than tracked as state.
static func vital_intact(wagons) -> bool:
	for wagon in wagons.wagons:
		var wagon_class: int = TYPE_TO_CLASS[wagon[Wagons.TYPE] - 1]
		if wagon_class in VITAL_CLASSES and (3 - wagon[Wagons.STATE]) <= 0:
			return false
	return true


# wdecor 0x067c-0x0716: enemy train composition from main[0x5eb4][idx][7] (strength).
# a = (strength/20)*4, b = strength%20+1, aggressiveness = min(5b+1, 99).
# n = rnd((a+b)/2) + (a+b)/2 + 1; trading = n*a/(a+b) + 1; final count = n+2.
static func enemy_composition(strength: int, rng: RandomNumberGenerator) -> Dictionary:
	var a := (strength / 20) * 4
	var b := (strength % 20) + 1
	var aggressiveness := mini(b * 5 + 1, 99)
	var half := (a + b) / 2
	var n := _rnd(rng, half) + half + 1
	var trading := (n * a) / (a + b) + 1
	var classes: Array = []
	classes.resize(n + 2)
	classes.fill(0)
	classes[0] = LOCOMOTIVE
	classes[1] = TENDER
	# wdecor 0x0743-0x07cc: place `trading` merchandise wagons among slots [2, n-1].
	# Up to 2 random picks per wagon (1 retry on an already-occupied slot); if both
	# picks collide and slot 2 happens to be free, the LAST tried slot is force-set
	# to merchandise anyway (0x079a writes LOC8398, not slot 2) — an original
	# collision oddity, not "fixed" here.
	for _placed in trading:
		var slot := _rnd(rng, n - 2) + 2
		var attempts := 1
		while classes[slot] != 0 and attempts < 2:
			slot = _rnd(rng, n - 2) + 2
			attempts += 1
		if classes[slot] == 0:
			classes[slot] = MERCHANDISE
		elif classes[2] == 0:
			classes[slot] = MERCHANDISE
	# wdecor 0x07d5-0x0899: remaining slots get barracks/livestock/machine gun/cannon
	# weighted 1/1/1/2 (rnd(5): 0->barracks, 1->livestock, 2->machine gun, 3 or 4->cannon).
	# Correction to combat.md §4 ("machine gun or cannon x2 weight"): only cannon is
	# doubled; machine gun carries the same weight as barracks and livestock.
	var quantities: Array = []
	quantities.resize(n + 2)
	quantities.fill(0)
	for i in range(2, n + 2):
		if classes[i] != 0:
			continue
		match _rnd(rng, 5):
			0:
				classes[i] = BARRACKS
				quantities[i] = _rnd(rng, b) * 4 + b + 1 # wdecor 0x080f
			1:
				classes[i] = LIVESTOCK
				quantities[i] = _rnd(rng, b) * 5 + b + 1 # wdecor 0x0837
			2:
				classes[i] = MACHINE_GUN
			_:
				classes[i] = CANNON
	return {"a": a, "b": b, "aggressiveness": aggressiveness, "classes": classes, "quantities": quantities}
