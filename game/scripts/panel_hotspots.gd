extends RefCounted

# Control panel hotspot table (yoda.alis 0x401-0x66b), disassembled 2026-09-27 with
# tools/alis_disasm.py directly at 0x43c and 0x522 (both switches on main+0x001c,
# base -1, 9 codes) and at 0x18b9 (reverser) and 0x672 (launcher gate).

const CODE_MAP_ICON := 1
const CODE_CLOCK := 2
const CODE_REVERSER := 3
const CODE_DETAILED_MAP := 4
const CODE_BRAKE := 5
const CODE_WAGON_A := 6 # main+0x0020 = 1 -> train.alis draws the engine (proven).
const CODE_WAGON_B := 7 # main+0x0020 = 2 -> General Quarters (INFERRED, per captain-crew.md).
const CODE_WAGON_C := 8 # main+0x0020 = 3 -> room.alis BOUDOIR (proven).
const CODE_LAUNCHER := 9

# 0x43c: shown while a map is up. 1 toggles detailed<->overall (0x1c39/0x1cda); 2
# clock; 3 reverser; 4 forces the detailed map; 5 brake; 6/7/8 select a wagon
# (main+0x0020 = code - 5); 9 launcher, gated on main+0x62c1 (bought) with the actual
# missile check inside the handler (see 0x672 below).
const MAP_VIEW_ACTIONS := {
	CODE_MAP_ICON: "toggle_map_scale",
	CODE_CLOCK: "toggle_clock",
	CODE_REVERSER: "reverse",
	CODE_DETAILED_MAP: "detailed_map",
	CODE_BRAKE: "toggle_brake",
	CODE_WAGON_A: "select_wagon",
	CODE_WAGON_B: "select_wagon",
	CODE_WAGON_C: "select_wagon",
	CODE_LAUNCHER: "open_launcher",
}

# 0x522: shown in a wagon or city. Corrects captain-crew.md's "3-5 do nothing (the
# manual confirms...)" from a manual-based claim to a disassembly-proven one: the
# switch targets for codes 3, 4 and 5 jump straight past the handler to the wait
# loop (0x66b) -- there is no code at all for those cases, not merely an inert one.
# Code 1 is not a bare "leave": it re-runs the same detailed<->overall logic as the
# map-view switch. Codes 6/7/8 add a same-wagon no-op guard (0x5fa: if the clicked
# wagon already equals main+0x0020, nothing happens). Code 9 adds a re-entry guard
# (main+0x2faa != -2, the launcher's own scene id) on top of the 0x43c gate.
const WAGON_CITY_ACTIONS := {
	CODE_MAP_ICON: "toggle_map_scale",
	CODE_CLOCK: "toggle_clock",
	CODE_REVERSER: "",
	CODE_DETAILED_MAP: "",
	CODE_BRAKE: "",
	CODE_WAGON_A: "select_wagon",
	CODE_WAGON_B: "select_wagon",
	CODE_WAGON_C: "select_wagon",
	CODE_LAUNCHER: "open_launcher",
}

const WAGON_SELECT_CODES := [CODE_WAGON_A, CODE_WAGON_B, CODE_WAGON_C]


# yoda.alis 0x4fe, 0x5c4, 0x5e6, 0x614: main+0x0020 = main+0x001c - 5.
static func selected_wagon_index(code: int) -> int:
	return code - 5


# yoda.alis 0x47c/0x57d: turning acceleration off sets time step 1; turning it on
# sets time step 3 (main+0x2fb8).
static func clock_toggle(accelerated: bool) -> Dictionary:
	return {"accelerated": not accelerated, "time_step": 1 if accelerated else 3}


# yoda.alis 0x4d1: main+0x614a toggles 0/1.
static func brake_toggle(braking: bool) -> Dictionary:
	return {"braking": not braking}


# yoda.alis 0x18b9-0x18e2: releases the brake unconditionally (main+0x614a = 0) as a
# side effect of reversing. The direction flip itself is inside jsr 0x18e3, which
# this tool could not decode (unsupported opcode in that path) -- NOT reproduced
# here; only the proven brake-release side effect is.
const REVERSER_RELEASES_BRAKE := true


# yoda.alis 0x672-0x6d6: sums main[0x2e1a][i][3] (QUANTITY) over wagons whose GOODS
# (main[0x2e1a][i][2]) == 2 (missiles). Zero -> textek 15; nonzero -> scene -2
# (berta/sbras, the launcher).
const NO_MISSILES_TEXTEK := 15
const LAUNCHER_SCENE := -2


# `bought` is main+0x62c1 != 0; `missiles` is the summed GOODS==2 quantity above.
static func launcher_action(bought: bool, missiles: int) -> Dictionary:
	if not bought:
		return {}
	if missiles <= 0:
		return {"kind": "textek", "id": NO_MISSILES_TEXTEK}
	return {"kind": "scene", "id": LAUNCHER_SCENE}


# Icon A/B/C placement (which drawn hotspot sends CODE_WAGON_A/B/C) is set by form
# data this tool has not decoded -- left undecoded per captain-crew.md's own
# confidence note; do not guess an assignment here.
const ICON_TO_CODE_UNDECODED := true
