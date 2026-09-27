extends RefCounted

# Train combat end conditions, booty and auto-resolve. Sources:
# wdecor.alis §8 (win/loss, win write-back and booty) and textek.alis §9
# (auto-resolve), both verified against reference-private/observations/
# combat-20260927/{wdecor.txt} and reference-private/observations/
# listings-20260927/textek.json (tools/claude/xdisasm.py + alis_pretty.py).
# Specification: tasks/evidence/combat.md.
#
# Out of scope here (needs combat_state.gd's tick simulation, not ported in
# this slice): the enemy-soldier/enemy-mammoth "survivor" pools that the win
# write-back distributes into BARRACKS/XL BARRACKS/livestock, and the exact
# per-wagon damage state written for captured trading wagons (wdecor 0x58d9/
# 0x5af1 read garbled operands even in the listing -- the disassembler itself
# emits "?" there). Where wdecor and textek share a formula this file exposes
# one function reused by both, cited at each call site.
const Setup = preload("res://scripts/combat_setup.gd")
const Wagons = preload("res://scripts/train_wagons.gd")

const MONEY_CAP := 31000 # glieu 0x565 / wdecor 0x5c86 / textek 0x4e75: same field, same cap.


static func _rnd(rng: RandomNumberGenerator, n: int) -> int:
	return rng.randi_range(0, n - 1) if n > 0 else 0


# --- §8 end-of-combat test (wdecor 0xef1-0xf43, structure confirmed; exact
# LOCw[0x215a]/[0x2160] indices are garbled in the listing) -----------------


# wdecor 0xf09/0xf23: win when enemy guns <= 0 AND enemy soldiers+mammoths <= 0.
static func is_win(enemy_guns: int, enemy_soldiers: int, enemy_mammoths: int) -> bool:
	return enemy_guns <= 0 and (enemy_soldiers + enemy_mammoths) <= 0


# wdecor 0xf27/0ab6: loss when your soldiers+mammoths <= 0 OR the vital flag is
# down. Your guns do not count, per combat.md §8.
static func is_loss(player_soldiers: int, player_mammoths: int, wagons) -> bool:
	return (player_soldiers + player_mammoths) <= 0 or not Setup.vital_intact(wagons)


# --- shared clamp (city_trade.gd::commit uses the identical pattern) -------


static func _clamp_lignite(engine) -> void:
	if engine.lignite < 0 or engine.lignite > MONEY_CAP:
		engine.lignite = MONEY_CAP


# --- destroyed-wagon side effects, shared by the win write-back loop -------
# (wdecor 0x5963-0x5a87). Applies to any wagon whose state is already 3;
# combat_state.gd (not ported) is responsible for setting that state.


# wdecor 0x5976-0x59c6: 2/3 of destroyed tenders cost 5000 lignite, 1/3 cost
# 5000 anthracite; either pool can go negative and is then covered from the
# other, floored at 0 (both fields, in that order).
static func _destroy_tender(engine, rng: RandomNumberGenerator) -> void:
	if _rnd(rng, 3) == 0:
		engine.anthracite -= 5000
	else:
		engine.lignite -= 5000
	if engine.lignite < 0:
		engine.anthracite += engine.lignite
		engine.lignite = 0
	if engine.anthracite < 0:
		engine.lignite += engine.anthracite
		engine.anthracite = 0
	if engine.lignite < 0:
		engine.lignite = 0


# wdecor 0x59f0-0x5a2f: a destroyed SPY wagon kills spies aboard (state 1 in
# main[0x5d84], 15 fields cleared each). This codebase does not yet model the
# full 20-slot/15-field spy record (captain-crew.md §4); city_trade.gd's
# spy_slots is a simplified 0/1 "aboard" array, which is what is cleared here.
static func _destroy_spy_wagon(spy_slots: Array) -> void:
	for i in spy_slots.size():
		if spy_slots[i] == 1:
			spy_slots[i] = 0


# wdecor 0x5963-0x5a87: apply per-type destruction effects, then clear goods
# and quantity for every destroyed wagon (any type, wdecor 0x5a6b/0x5a79).
static func apply_destruction(wagons, engine, spy_slots: Array, rng: RandomNumberGenerator) -> void:
	for wagon in wagons.wagons:
		if wagon[Wagons.STATE] != 3:
			continue
		if wagon[Wagons.TYPE] == Setup.TYPE_TENDER:
			_destroy_tender(engine, rng)
		elif wagon[Wagons.TYPE] == Setup.TYPE_SPY:
			_destroy_spy_wagon(spy_slots)
		wagon[Wagons.QUANTITY] = 0
		wagon[Wagons.GOODS] = 0


# --- booty: lignite (wdecor 0x5be2 win / textek 0x4de6 auto-resolve) -------


# wdecor 0x5be2-0x5ca4: win-path coal. `n` is the enemy wagon count (n+2 from
# enemy_composition, i.e. olocb[8362] reused for this purpose in the listing).
static func win_coal(wagons, engine, n: int, rng: RandomNumberGenerator) -> void:
	var raw := (n * 2 + _rnd(rng, 50)) * 10
	_apply_coal(wagons, engine, raw)


# textek 0x4de6-0x4e93: auto-resolve coal. Same shape as win_coal but with an
# extra "+1" inside the parenthesis before the *10 (combat.md §9: "+1 in coal").
static func auto_resolve_coal(wagons, engine, n: int, rng: RandomNumberGenerator) -> void:
	var raw := (n * 2 + _rnd(rng, 50) + 1) * 10
	_apply_coal(wagons, engine, raw)


static func _apply_coal(wagons, engine, raw: int) -> void:
	var tender_room := 0
	for wagon in wagons.wagons:
		if wagon[Wagons.TYPE] == Setup.TYPE_TENDER and wagon[Wagons.STATE] != 3:
			tender_room += 5000
	tender_room -= engine.lignite + engine.anthracite
	if tender_room < 0:
		tender_room = 0
	engine.lignite += mini(raw, tender_room)
	_clamp_lignite(engine)


# --- booty: slaves into PRISON/ALCATRAZ -------------------------------------


# wdecor 0x5cab-0x5dc5 (win, gate 60) / textek 0x4eee-0x502a (auto-resolve,
# gate 30 -- combat.md §9 "prison qty<30" oddity, kept exactly: the ENTRY
# check uses 30 but wagons still fill up TO 60). Returns the count placed.
static func distribute_slaves(wagons, total: int, prison_gate: int) -> int:
	var remaining := total
	for wagon in wagons.wagons:
		if remaining <= 0:
			break
		if wagon[Wagons.STATE] == 3:
			continue
		var cap := -1
		if wagon[Wagons.TYPE] == Setup.TYPE_PRISON and wagon[Wagons.QUANTITY] < prison_gate:
			cap = 60
		elif wagon[Wagons.TYPE] == Setup.TYPE_ALCATRAZ and wagon[Wagons.QUANTITY] < 100:
			cap = 100
		else:
			continue
		var take: int = mini(cap - wagon[Wagons.QUANTITY], remaining)
		wagon[Wagons.QUANTITY] += take
		remaining -= take
	return total - remaining


static func win_slaves(wagons, n: int, rng: RandomNumberGenerator) -> int:
	return distribute_slaves(wagons, n * 3 + _rnd(rng, n * 3), 60) # wdecor 0x5cab


static func auto_resolve_slaves(wagons, n: int, rng: RandomNumberGenerator) -> int:
	return distribute_slaves(wagons, n * 3 + _rnd(rng, n * 3), 30) # textek 0x4eee


# --- booty: win-only survivors/mammoths (pool sizes come from combat_state.gd,
# not ported; these take the pool as an input so they are testable now) -----


# wdecor 0x5df5-0x6053: survivors into BARRACKS (<=50) then XL BARRACKS
# (<=100, despite the manual's description of 80 -- combat.md's named oddity,
# confirmed exact at wdecor 0x5ee8). Overflow lost.
static func win_survivors(wagons, total: int) -> int:
	var remaining := total
	for wagon in wagons.wagons:
		if remaining <= 0:
			break
		if wagon[Wagons.STATE] == 3:
			continue
		var cap := -1
		if wagon[Wagons.TYPE] == Setup.TYPE_BARRACKS and wagon[Wagons.QUANTITY] < 50:
			cap = 50
		elif wagon[Wagons.TYPE] == Setup.TYPE_XL_BARRACKS and wagon[Wagons.QUANTITY] < 100:
			cap = 100
		else:
			continue
		var take: int = mini(cap - wagon[Wagons.QUANTITY], remaining)
		wagon[Wagons.QUANTITY] += take
		remaining -= take
	return total - remaining


# wdecor 0x5f79-0x6053: mammoths into livestock wagons, cap 5 per wagon.
static func win_mammoths(wagons, total: int) -> int:
	var remaining := total
	for wagon in wagons.wagons:
		if remaining <= 0:
			break
		if wagon[Wagons.STATE] == 3 or wagon[Wagons.TYPE] != Setup.TYPE_LIVESTOCK:
			continue
		var take: int = mini(5 - wagon[Wagons.QUANTITY], remaining)
		if take <= 0:
			continue
		wagon[Wagons.QUANTITY] += take
		remaining -= take
	return total - remaining


# --- booty: captured trading wagons, shared formula -------------------------
# wdecor 0x5aa5-0x5bad (win, up to 6) and textek 0x5974-0x5a56 (auto-resolve,
# count = min(margin, 8)): byte-identical goods/capacity sub-formula in both
# listings once the goods-capacity cswitch2 is resolved for its only reachable
# inputs (roll = rnd(16)+1 is always >= 1): capacity is always 40; goods stays
# `roll` only when roll == 3, otherwise it is replaced by 10+rnd(7).
static func capture_trading_wagons(wagons, count: int, rng: RandomNumberGenerator) -> void:
	for _i in maxi(0, count):
		if wagons.count() >= Wagons.MAX_WAGONS:
			break
		var wagon_type := 17 + _rnd(rng, 2) # MERCHANDISE or XL MERCHANDISE, 50/50
		var roll := _rnd(rng, 16) + 1
		var goods := roll if roll == 3 else 10 + _rnd(rng, 7)
		var capacity := 40
		var quantity := (_rnd(rng, capacity / 2) + 1) if wagon_type == 17 else (_rnd(rng, capacity) + 1)
		wagons.wagons.append([wagon_type, 0, goods, quantity])


# --- §9 auto-resolve (textek 0x49fc) ----------------------------------------


# textek 0x4a30-0x4a96: potential pools, gated by state < 3 (non-scrap).
# Reads main[0x2e1a][i][0] directly, a different namespace from combat_setup's
# wdecor "class" table (see combat_setup.gd's header note).
static func auto_resolve_pools(wagons) -> Dictionary:
	var soldiers := 0
	var mammoths := 0
	var guns := 0
	for wagon in wagons.wagons:
		if wagon[Wagons.STATE] >= 3:
			continue
		match wagon[Wagons.TYPE]:
			Setup.TYPE_LIVESTOCK:
				mammoths += wagon[Wagons.QUANTITY]
			Setup.TYPE_CANNON, Setup.TYPE_MACHINE_GUN:
				guns += 1
			Setup.TYPE_BARRACKS, Setup.TYPE_XL_BARRACKS:
				soldiers += wagon[Wagons.QUANTITY]
	return {"soldiers": soldiers, "mammoths": mammoths, "guns": guns}


# textek 0x4aab: P = (soldiers + mammoths*20 + guns*50) / 50.
static func potential(pools: Dictionary) -> int:
	return (pools.soldiers + pools.mammoths * 20 + pools.guns * 50) / 50


# textek 0x4ac8/0x4b04: margin = P - strength/100.
static func margin(pot: int, strength: int) -> int:
	return pot - strength / 100


# textek 0x5435: game over (message 105) when margin <= 0.
static func auto_resolve_game_over(m: int) -> bool:
	return m <= 0


# textek 0x4c11/0x4c95: casualties are x - x/(margin+1). As written, and kept
# exactly per the task's instruction not to "fix" it: a larger margin removes
# MORE of the pool, not less (combat.md's named oddity).
static func auto_resolve_casualties(pool: int, m: int) -> int:
	return pool - pool / (m + 1)


# textek 0x4de6 region (caller-side, not shown at that offset): scrap count.
# combat.md: "9-m random wagons of types 4-20 are scrapped". Clamped at 0
# here since the source is an unrolled fixed set of call sites that simply
# stop early (no negative-count case exists in the bytecode to observe).
static func auto_resolve_scrap_count(m: int) -> int:
	return maxi(0, 9 - m)


# textek 0x4dd4 region: captured merchandise count = min(margin, 8).
static func auto_resolve_captured_count(m: int) -> int:
	return mini(m, 8)


# textek 0x58a1-0x5973: destroy one random wagon of type 4-20 (17 types,
# excluding locomotive/tender/GQ/boudoir/cannon/MG/merchandise-XL/barracks/XL
# via the type>3 & type!=21 & type!=22 & type<23 filter). At most 2 random
# picks: the first pick that fails the type filter gives up immediately (no
# retry); a destroyed (state==3) first pick retries once; a destroyed second
# pick also gives up. Matches combat.md's "types 4-20" note exactly.
static func _scrap_one(wagons, rng: RandomNumberGenerator) -> void:
	for _attempt in 2:
		var index := _rnd(rng, wagons.wagons.size())
		var wagon: Array = wagons.wagons[index]
		var wagon_type: int = wagon[Wagons.TYPE]
		if wagon_type <= 3 or wagon_type == Setup.TYPE_TENDER or wagon_type >= Setup.TYPE_SPY:
			return
		if wagon[Wagons.STATE] != 3:
			wagon[Wagons.STATE] = 3
			wagon[Wagons.GOODS] = 0
			wagon[Wagons.QUANTITY] = 0
			return


static func scrap_wagons(wagons, count: int, rng: RandomNumberGenerator) -> void:
	for _i in maxi(0, count):
		_scrap_one(wagons, rng)
