extends RefCounted

# BOUDOIR (room.alis, main+0x0020 == 3, hotspot switch at 0xc0; all offsets
# disassembled 2026-09-27 with tools/alis_disasm.py). Does not touch main.gd; the
# save entry point produces a pure (name, state) -> {filename, data} mapping the
# caller applies however the remake persists saves.

const STOUP_CODE := 10
const KOLOTOV_CODE := 11
const REVOLVER_CODE := 12
const BOOK_CODE := 13

# room.alis 0xd4-0x191: switch base -10 dispatch targets, matching the code table.
static func dispatch(code: int, stoup) -> Dictionary:
	match code:
		STOUP_CODE:
			return {"kind": "stoup"} if stoup.has_pending() else {}
		KOLOTOV_CODE:
			return open_inventory()
		REVOLVER_CODE:
			return {"kind": "revolver_prompt", "message": REVOLVER_PROMPT}
		BOOK_CODE:
			return {"kind": "save_prompt", "message": NAME_PROMPT}
	return {}


# room.alis 0xe4-0x11d: fade, texte2k 100 "INVENTORY", main+0x651b = 1 and
# main+0x2fcc = 0 while shown, restored to 0/original on close. captain-crew.md
# marks the pause effect INFERRED, not proven; carried forward as such here.
const KOLOTOV_MESSAGE := 100 # texte2k 100

static func open_inventory() -> Dictionary:
	return {"kind": "inventory", "message": KOLOTOV_MESSAGE, "pauses_clock": true} # pauses_clock: inferred.


# room.alis 0x121-0x18d: textek 97 prompt, then a two-button wait. Which physical
# button is "confirm" vs "cancel" is a souris.alis mouse-code question (main+0x1f),
# out of this module's scope; the two outcomes below are what each branch does.
const REVOLVER_PROMPT := 97 # "IN ORDER TO COMMIT SUICIDE / PRESS THE LEFT BUTTON / OR THE RIGHT BUTTON TO CANCEL"
const GAME_OVER_IMAGE := 21
const GAME_OVER_LAYER := 77
const GAME_OVER_YODA_MSG := 26
const EPITAPH_SUICIDE := 100 # texte2k 100 (switch base -100 at 0x26d0): the suicide epitaph.

static func revolver_confirm() -> Dictionary:
	return {
		"kind": "game_over",
		"image": GAME_OVER_IMAGE,
		"layer": GAME_OVER_LAYER,
		"yoda_msg": GAME_OVER_YODA_MSG,
		"param": EPITAPH_SUICIDE,
		"epitaph_id": EPITAPH_SUICIDE,
	}


static func revolver_cancel() -> Dictionary:
	return {}


# room.alis 0x55e-0x5e0+: textek 38 prompt, then per-key filtering. Verified: a
# lowercase letter is folded to uppercase (-32) before the charset check; accepted
# keys are A-Z, 0-9, backspace (8, deletes the last char) and 187 (confirm/return).
const NAME_PROMPT := 38 # "ENTER THE NAME OF YOUR BACKUP / THEN PRESS RETURN : / TO CANCEL TYPE F1"
const NAME_MAX_LEN := 8
const BACKSPACE_KEY := 8
const CONFIRM_KEY := 187


static func _normalize_key(key: int) -> int:
	if key >= 97 and key <= 122: # a-z
		return key - 32
	return key


static func is_name_char(key: int) -> bool:
	var k := _normalize_key(key)
	return (k >= 65 and k <= 90) or (k >= 48 and k <= 57) # A-Z or 0-9


# precondition: `name` is a prefix already accepted by this function.
# postcondition: backspace removes the last character; an accepted char is appended
# while name.length() < NAME_MAX_LEN; any other key (including CONFIRM_KEY, which the
# caller checks separately) leaves `name` unchanged.
static func append_char(name: String, key: int) -> String:
	if key == BACKSPACE_KEY:
		return name.substr(0, maxi(0, name.length() - 1))
	if is_name_char(key) and name.length() < NAME_MAX_LEN:
		return name + char(_normalize_key(key))
	return name


static func is_confirm(key: int) -> bool:
	return key == CONFIRM_KEY


static func save_filename(name: String) -> String:
	return "%s.SAV" % name


# Pure mapper: (validated name, caller-assembled state dict) -> {filename, data}.
# `state` is whatever the remake's own save representation is (main.gd's save_view()
# dict shape, per its "version"/"wagons"/"trade"/... keys) -- this function does not
# assemble it and does not touch main.gd. Returns {} for an empty name (room.alis
# never reaches the write with zero characters entered; F1 cancels first).
static func build_save(name: String, state: Dictionary) -> Dictionary:
	if name.is_empty():
		return {}
	return {"filename": save_filename(name), "data": state}
