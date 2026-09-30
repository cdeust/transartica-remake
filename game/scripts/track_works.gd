extends RefCounted

# Track works in front of a blocked cell: crevasse, lake, destroyed track.
# Source: tasks/evidence/obstacles.md (TIME 0x2401/0x24ed messages, YODA 0x2390 handler).
const Wagons = preload("res://scripts/train_wagons.gd")

const RAILS_GOODS := 1 # commerce goods 1 = RAILS (reference-private/commerce.json goods_names).
const RAIL_WAGONS := [17, 18] # MERCHANDISE, XL MERCHANDISE (YODA 0x23ba).
const SLAVE_WAGONS := [5, 6] # PRISON, ALCATRAZ (YODA 0x23ba).
const DESTROYED_LIMIT := -105 # TIME 0x2401: -105 < tile < 0 is destroyed track.

# question/lack: TEXTEK message ids; work: TEXTEK work screen id (74..76).
# consume = base - rnd(spread); rnd(n) is 0..n-1 (opernames.c:433).
const WORKS := {
	"crevasse": {"question": 24, "lack": 92, "rails": 10, "slaves": 15, "work": 74, "base": 20, "spread": 5},
	"lake": {"question": 25, "lack": 93, "rails": 8, "slaves": 15, "work": 75, "base": 25, "spread": 5},
	"destroyed": {"question": 26, "lack": 94, "rails": 2, "slaves": 5, "work": 76, "base": 2, "spread": 0},
}
# YODA map writes on success: crevasse 67->63, 69->64; lake -116->-121, 114->-117.
const REPAIRED := {67: 63, 69: 64, -116: -121, 114: -117}


static func kind_for(code: int) -> String:
	if code == 67 or code == 69:
		return "crevasse"
	if code == -116 or code == 114:
		return "lake"
	if code < 0 and code > DESTROYED_LIMIT:
		return "destroyed"
	return ""


static func repaired_code(code: int) -> int:
	return REPAIRED.get(code, absi(code))


static func rails_carried(wagons) -> int:
	var total := 0
	for wagon in wagons.wagons:
		if wagon[Wagons.TYPE] in RAIL_WAGONS and wagon[Wagons.GOODS] == RAILS_GOODS:
			total += wagon[Wagons.QUANTITY]
	return total


static func slaves_carried(wagons) -> int:
	var total := 0
	for wagon in wagons.wagons:
		if wagon[Wagons.TYPE] in SLAVE_WAGONS:
			total += wagon[Wagons.QUANTITY]
	return total


# YODA 0x243c then 0x2482: rails are checked before slaves. "" when the work can start.
static func shortage(kind: String, wagons) -> String:
	var work: Dictionary = WORKS[kind]
	if rails_carried(wagons) < work.rails:
		return "rails"
	if slaves_carried(wagons) < work.slaves:
		return "slaves"
	return ""


static func rails_needed(kind: String, rng: RandomNumberGenerator) -> int:
	var work: Dictionary = WORKS[kind]
	if work.spread == 0:
		return work.base
	return work.base - rng.randi_range(0, work.spread - 1)


# TEXTEK 0x41d6: subtract from RAILS wagons in order; an emptied wagon loses its goods.
static func consume_rails(wagons, amount: int) -> int:
	var left := amount
	for wagon in wagons.wagons:
		if left <= 0:
			break
		if not wagon[Wagons.TYPE] in RAIL_WAGONS or wagon[Wagons.GOODS] != RAILS_GOODS:
			continue
		var taken := mini(left, wagon[Wagons.QUANTITY])
		wagon[Wagons.QUANTITY] -= taken
		left -= taken
		# TEXTEK0x42bd: exact empty retains goods; only undershoot clears.
		if wagon[Wagons.QUANTITY] == 0 and left > 0:
			wagon[Wagons.GOODS] = 0
	return amount - left


# TEXTEK 0x4200..0x4406: counts all loaded labour, including damaged wagons;
# any crane adds 150 once. Countdown ticks are TEXTEK ticks, not simulated minutes.
static func work_report(kind: String, wagons) -> Dictionary:
	var slaves := slaves_carried(wagons)
	var mammoths := 0
	var cranes := 0
	for wagon in wagons.wagons:
		if wagon[Wagons.TYPE] == 7:
			mammoths += int(wagon[Wagons.QUANTITY])
		elif wagon[Wagons.TYPE] == 16:
			cranes += 1
	var labour := slaves + mammoths * 30 + (150 if cranes > 0 else 0)
	var remaining := maxi(0, (175 if kind == "destroyed" else 420) - labour)
	var ticks: int = remaining / 3 + (12 if kind == "destroyed" else 144)
	# ALIS slocb writes8bits and olocb reads signed8bits (storenames.c:42,
	# opernames.c:114). TEXTEK0x43e7/43f8 assigns L0x16b, not a word.
	ticks &= 255
	if ticks > 127:
		ticks -= 256
	return {"slaves": slaves, "mammoths": mammoths, "cranes": cranes, "ticks": ticks}
