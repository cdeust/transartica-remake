extends RefCounted

# Kolotov's inventory (textek 0x2be7-0x3171, disassembled 2026-09-27). Returns
# structured lines; no drawing (rendering is another agent's concern).
const Wagons = preload("res://scripts/train_wagons.gd")
const CityTrade = preload("res://scripts/city_trade.gd")

const DESTROYED_STATE := 3 # main[0x2e1a][i][1] == 3 (train_wagons.gd STATE).

# textek 0x2c85-0x2cc4: PTAV totals main[0x2e1a] tare weight. A destroyed wagon
# contributes a flat 10 regardless of type; an intact wagon contributes its type's
# TIME 0x2a77 base weight. Independently re-derived at textek.alis 0x36ae (a 24-case
# switch on wagon type) and found byte-for-byte identical to train_wagons.gd's
# BASE_WEIGHT for types 1-24 -- confirms that table. Type 25 (BOILER) has no case in
# this switch (falls through with a stale weight): the original's behaviour for a
# destroyed-state check aside, an intact BOILER's PTAV contribution is NOT decoded
# here; train_wagons.gd's BASE_WEIGHT[24]=200 is used as the safe value pending
# further decoding, per AGENTS.md (do not substitute a guessed rule silently -- this
# comment is the flag).
static func ptav(wagons) -> int:
	var total := 0
	for wagon in wagons.wagons:
		if wagon[Wagons.STATE] == DESTROYED_STATE:
			total += 10
		else:
			total += Wagons.BASE_WEIGHT[wagon[Wagons.TYPE] - 1]
	return total


# textek 0x37ba-0x37f3: load contribution per intact wagon, folded into PTAC only
# (destroyed wagons contribute no load; textek 0x2ca5 skips the accumulation for
# them). Correction to train_wagons.gd's own `_load_weight`: that function treats
# type 21 (TENDER) the same as type 7 (quantity * 10). The inventory routine does
# NOT: for a TENDER it discards main[0x2e1a][i][3] entirely and adds the CURRENT
# global fuel load (main+0x2fb6 lignite + main+0x2fc8 anthracite) instead -- once per
# intact tender present, reproduced verbatim here even though it reads like an
# original-engine quirk (multiple tenders each add the same global total).
static func _load_weight(wagon_type: int, quantity: int, engine) -> int:
	match wagon_type:
		5, 6, 23, 24:
			return quantity / 10
		7:
			return quantity * 10
		CityTrade.TENDER_TYPE: # 21; see the comment above for why this ignores `quantity`.
			return engine.lignite + engine.anthracite
		14, 15, 17, 18, 19:
			return quantity
	return 0


# PTAC (textek 0x2d4d): printed as PTAV + the load total above, i.e. "total weight
# loaded" = tare + cargo, not cargo alone.
static func ptac(wagons, engine) -> int:
	var load_total := 0
	for wagon in wagons.wagons:
		if wagon[Wagons.STATE] != DESTROYED_STATE:
			load_total += _load_weight(wagon[Wagons.TYPE], wagon[Wagons.QUANTITY], engine)
	return ptav(wagons) + load_total


# textek 0x2d67-0x2da2: 5000 per intact tender (TYPE 21, STATE != 3), a second pass
# independent of the PTAV/PTAC loop above.
static func tender_capacity(wagons) -> int:
	var count := 0
	for wagon in wagons.wagons:
		if wagon[Wagons.TYPE] == CityTrade.TENDER_TYPE and wagon[Wagons.STATE] != CityTrade.SCRAP_STATE:
			count += 1
	return count * CityTrade.COAL_PER_TENDER


# textek 0x2dec: main+0x2fb6 (lignite) + main+0x2fc8 (anthracite).
static func present_contents(engine) -> int:
	return engine.lignite + engine.anthracite


static func destroyed_count(wagons) -> int:
	var count := 0
	for wagon in wagons.wagons:
		if wagon[Wagons.STATE] == DESTROYED_STATE:
			count += 1
	return count


# textek 0x33fc-0x3477: "CONTAINING n <suffix>" per type, exact decoded strings.
const CONTENTS_SUFFIX := {
	5: "SLAVE(S)", 6: "SLAVE(S)",
	7: "MAMMOTH(S)",
	15: "TON(S) OF OIL",
	19: "TON(S) OF PLANTS",
	22: "SPY (SPIES)",
	23: "SOLDIER(S)", 24: "SOLDIER(S)",
}

# Order of "NAME: count" lines, one per intact type present (captain-crew.md §2,
# already marked proven there; not re-derived here for lack of time -- see the
# Portage note in tasks/evidence/captain-crew.md). Type 25 (BOILER) is absent from
# this list in the evidence too.
const TYPE_ORDER := [1, 2, 3, 21, 8, 9, 10, 11, 12, 13, 4, 16, 20, 22, 23, 24, 5, 6, 7, 14, 15, 17, 18, 19]


# Returns one entry per intact type present, in TYPE_ORDER, each
# {"type": int, "name": String, "count": int, "contents": String or ""}.
# `trade` supplies wagon_name(); pass null to get "TYPE n" placeholders (tests, or
# before commerce.json is loaded).
static func type_lines(wagons, trade) -> Array:
	var counts := {}
	var quantities := {}
	for wagon in wagons.wagons:
		if wagon[Wagons.STATE] == DESTROYED_STATE:
			continue
		var wagon_type: int = wagon[Wagons.TYPE]
		counts[wagon_type] = counts.get(wagon_type, 0) + 1
		# textek 0x33fc-0x3477: sum contents of intact wagons of this type.
		quantities[wagon_type] = quantities.get(wagon_type, 0) + wagon[Wagons.QUANTITY]
	var lines: Array = []
	for wagon_type in TYPE_ORDER:
		if not counts.has(wagon_type):
			continue
		var name := "TYPE %d" % wagon_type
		if trade != null and trade.data.has("wagon_names"):
			name = trade.wagon_name(wagon_type)
		lines.append({
			"type": wagon_type,
			"name": name,
			"count": counts[wagon_type],
			"quantity": quantities[wagon_type],
			"contents": CONTENTS_SUFFIX.get(wagon_type, ""),
		})
	return lines


# textek 0x2be7-0x2c71: header lines (main+0x2fb2 = DAY). textek 0x3809: a new page
# starts on click, incrementing PAGE (how many lines fit before the click prompt is
# not decoded; "no drawing" per the task -- pagination itself is the caller's job).
# `day` is taken as a parameter: no day-of-journey counter exists yet anywhere in
# the remake's engine_*/travel_*/main.gd (grepped, none found), and engine_*.gd is
# out of this module's scope to add one to.
static func header(day: int, wagons, page := 1) -> Dictionary:
	return {
		"day": day,
		"page": page,
		"wagon_count": wagons.count(),
		"destroyed": destroyed_count(wagons),
	}


# One call assembling the full structured report (header + weights + type lines).
static func build(day: int, engine, wagons, trade, page := 1) -> Dictionary:
	var result := header(day, wagons, page)
	result.ptav = ptav(wagons)
	result.ptac = ptac(wagons, engine)
	result.tender_capacity = tender_capacity(wagons)
	result.present_contents = present_contents(engine)
	result.lines = type_lines(wagons, trade)
	return result
