extends RefCounted

# General Quarters (train.alis, main+0x0020 == 2, entry 0xe19; menus 0xfb5 and 0x1042;
# all offsets disassembled 2026-09-27 with tools/alis_disasm.py). Ports the rules up to
# the point they hand off to yoda/map/scene scripts: those effects are returned as a
# typed {"kind": "yoda_msg", "id": ...} result, not invented.
const Wagons = preload("res://scripts/train_wagons.gd")

const STOUP_CODE := 10
const SPY_MENU_CODE := 11
const MAP_CODE := 12
const CAR_MENU_CODE := 13

const NO_SPIES_TEXTEK := 9 # "YOU DON'T HAVE ANY SPIES / AND YOU CANNOT ACCESS THIS MENU"
const NO_CARS_TEXTEK := 8 # "YOU HAVE NO LINE INSPECTION CARS / AND YOU CANNOT ACCESS THIS MENU"
const OVERALL_MAP_YODA_MSG := 1

const SPY_MENU_SEND_CODE := 10
const SPY_MENU_DYNAMITE_CODE := 11
const SPY_MENU_EXIT_CODE := 12
const SEND_SPY_YODA_MSG := 12
const DYNAMITE_YODA_MSG := 13

const CAR_MENU_PLAIN_CODE := 10
const CAR_MENU_MISSILE_CODE := 11
const CAR_MENU_EXIT_CODE := 12
const PLAIN_CAR_YODA_MSG := 10
const MISSILE_CAR_YODA_MSG := 11

# main[0x5d84][k][0] states (captain-crew.md §4, proven).
const STATE_FREE := 0
const STATE_ABOARD := 1
const STATE_TRAVELLING := 2
const STATE_POSTED := 3
const SPY_SLOT_COUNT := 20

const CAR_GOODS := 3 # main[0x2e1a][i][2] (GOODS) == 3: plain inspection car load.
const MISSILE_GOODS := 2 # GOODS == 2: missile load.


# train.alis 0xe79-0xeb5: a single pass over the 20 spy records sets both flags; the
# switch shows the menu only if at least one is set.
static func can_send_spy(spy_records: Array) -> bool:
	for state in spy_records:
		if state == STATE_ABOARD:
			return true
	return false


static func can_dynamite(spy_records: Array) -> bool:
	for state in spy_records:
		if state == STATE_TRAVELLING or state == STATE_POSTED:
			return true
	return false


static func _goods_total(wagons, goods: int) -> int:
	var total := 0
	for wagon in wagons.wagons:
		if wagon[Wagons.GOODS] == goods:
			total += wagon[Wagons.QUANTITY]
	return total


# train.alis 0xf2a-0xf8a: L0x10w, summed over intact and destroyed wagons alike (the
# loop does not check STATE) -- GOODS == 3 gates the car menu.
static func cars_count(wagons) -> int:
	return _goods_total(wagons, CAR_GOODS)


static func missiles_count(wagons) -> int:
	return _goods_total(wagons, MISSILE_GOODS)


# train.alis 0xe3b switch (codes 10-13). `stoup` is a stoup_messages.gd instance.
static func dispatch(code: int, wagons, spy_records: Array, stoup) -> Dictionary:
	match code:
		STOUP_CODE:
			return {"kind": "stoup"} if stoup.has_pending() else {}
		SPY_MENU_CODE:
			if can_send_spy(spy_records) or can_dynamite(spy_records):
				return {"kind": "spy_menu"}
			return {"kind": "textek", "id": NO_SPIES_TEXTEK}
		MAP_CODE:
			return {"kind": "yoda_msg", "id": OVERALL_MAP_YODA_MSG}
		CAR_MENU_CODE:
			if cars_count(wagons) > 0:
				return {"kind": "car_menu"}
			return {"kind": "textek", "id": NO_CARS_TEXTEK}
	return {}


# train.alis 0xfff switch (codes 10-12), only reachable once dispatch() opened the
# menu, so the availability re-check mirrors 0x1013/0x1026 (silently does nothing if
# the option is not available -- the original never shows a disabled option firing).
static func spy_menu_action(code: int, spy_records: Array) -> Dictionary:
	match code:
		SPY_MENU_SEND_CODE:
			return {"kind": "yoda_msg", "id": SEND_SPY_YODA_MSG} if can_send_spy(spy_records) else {}
		SPY_MENU_DYNAMITE_CODE:
			return {"kind": "yoda_msg", "id": DYNAMITE_YODA_MSG} if can_dynamite(spy_records) else {}
		SPY_MENU_EXIT_CODE:
			return {"kind": "exit"}
	return {}


# train.alis 0x1070 switch (codes 10-12). Code 10 (plain car) is unconditional once
# the menu is open (0x1082, no guard); code 11 (missile car) re-checks L0x14w.
static func car_menu_action(code: int, wagons) -> Dictionary:
	match code:
		CAR_MENU_PLAIN_CODE:
			return {"kind": "yoda_msg", "id": PLAIN_CAR_YODA_MSG}
		CAR_MENU_MISSILE_CODE:
			return {"kind": "yoda_msg", "id": MISSILE_CAR_YODA_MSG} if missiles_count(wagons) > 0 else {}
		CAR_MENU_EXIT_CODE:
			return {"kind": "exit"}
	return {}
