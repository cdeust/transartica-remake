extends "res://scripts/campaign_spies.gd"

# MIT. Source: tasks/evidence/campaign-completion.md and exact unpacked ECS offsets.
const DELIVERY_CODE := "58947" # SCENE4 0x22..46 ASCII53,56,57,52,55; TEXTEK51.
var urga_key := false # SCENE3 0x102 main64f5.
var delivery_open := false # SCENE4 0x2f6 main6514.
var whale_present := true # TABLE0x25b main6517; YODA0x1479 clears.
var sos_sent := false # SCENE4 0x345 main6536.
var pending: Dictionary = {}
var ending := ""
var data: Dictionary = {}
var hazards = preload("res://scripts/campaign_hazards.gd").new()
var fauna = preload("res://scripts/campaign_fauna.gd").new()
var protection_seen := {"soleil": false, "viking": false}


func _init() -> void:
	reset()


func reset() -> void:
	urga_key = false
	delivery_open = false
	central_destroyed = false
	whale_present = true
	sos_sent = false
	pending = {}
	ending = ""
	hazards = preload("res://scripts/campaign_hazards.gd").new()
	fauna = preload("res://scripts/campaign_fauna.gd").new()
	protection_seen = {"soleil": false, "viking": false}
	spies.clear()
	for index in SPY_COUNT:
		var record: Array = []
		record.resize(SPY_FIELDS)
		record.fill(0)
		spies.append(record)


func load_data(path: String = "res://private-data/campaign.json") -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("version") != 1:
		return false
	data = parsed
	return true


func message(id: int, epitaph := false) -> Array[String]:
	var result: Array[String] = []
	var section := "epitaphs" if epitaph and id >= 100 and id <= 105 else "documents" if epitaph else "messages"
	for line in data.get(section, {}).get(str(id), []):
		result.append(str(line))
	return result


# TIME0x1b9d called before station/obstacle dispatch. Reveal only matching -115.
func prepare_entry(cell: Vector2i, heading: int, wagons, network) -> Dictionary:
	if not pending.is_empty() or not ending.is_empty():
		return pending
	var spy := posted_at(cell)
	if spy >= 0:
		return _event("spy_pickup", [21], {"spy": spy})
	var code: int = network.tile(cell)
	if cell.x > 38 and cell.x < 59 and cell.y > 19 and cell.y < 34:
		if cell == Vector2i(39, 32) and code == 34:
			network.set_campaign_tile(cell, 2) # TIME0x1fc8.
		_reveal(cell, "hima", 0, network)
	elif cell.x > 138 and cell.x < 158 and cell.y > 46 and cell.y < 69:
		if cell == Vector2i(157, 68) and code == 36 and central_destroyed:
			network.set_campaign_tile(cell, 3) # TIME0x1e98.
		_reveal(cell, "trans", 256, network)
		if cell == Vector2i(152, 48) and heading == 1 and wagons.count() > 5:
			var boiler := false
			for wagon in wagons.wagons:
				boiler = boiler or wagon[W.TYPE] == 25 # TIME0x1f53 no state test.
			if not boiler:
				return _event("slope", [18])
	else:
		if cell == Vector2i(11, 10) and whale_present:
			var harpoon := false
			for wagon in wagons.wagons:
				harpoon = harpoon or (wagon[W.TYPE] == 9 and wagon[W.STATE] < 3)
			if harpoon:
				whale_present = false # YODA0x1479.
				return _event("whale_harpoon", [53], {"reverse": true})
			return _event("whale_question", [28], {"epitaph": 104})
		if cell.y == 67:
			if cell.x == 32 and code == 35 and (wagons.wagons.front()[W.TYPE] == 8 or wagons.wagons.back()[W.TYPE] == 8):
				network.set_campaign_tile(cell, 2) # TIME0x1c31–7b.
			var changed := {28: [88, 54], 29: [89, -114], 30: [90, -113]}
			if changed.has(cell.x) and code == changed[cell.x][0]:
				network.set_campaign_tile(cell, changed[cell.x][1])
			_reveal(cell, "oasis", 0, network)
	return {}


func _reveal(cell: Vector2i, region: String, x_adjust: int, network) -> void:
	if network.tile(cell) != -115:
		return
	for record in data.get("regions", {}).get(region, []):
		if Vector2i(int(record[0]) + x_adjust, int(record[1])) == cell:
			network.set_campaign_tile(cell, int(record[2]))
			return


# TIME0x26fb station dispatch and YODA scenes -8,-10,-6 and message25.
func station(index: int, network) -> Dictionary:
	match index:
		-2:
			network.set_campaign_tile(Vector2i(22, 67), -122)
			if urga_key:
				return _event("urga", [88])
			urga_key = true
			return _event("urga", [86, 87])
		-3:
			network.set_campaign_tile(Vector2i(34, 4), 80)
			return _event("oslo", [89, 90], {"code_input": urga_key, "quiz_done": false})
		-4:
			network.set_campaign_tile(Vector2i(52, 32), -123)
			return _event("mausoleum", [51])
		-5:
			ending = "sun"
			return _event("sun", [19])
	return {}


func _event(scene: String, messages: Array, extra: Dictionary = {}) -> Dictionary:
	pending = {"scene": scene, "messages": messages}
	pending.merge(extra)
	return pending.duplicate(true)


func submit_code(text: String, stoup = null) -> Dictionary:
	if not urga_key or pending.get("scene") != "oslo" or not pending.get("code_input", false) or not pending.get("quiz_done", false) or text != DELIVERY_CODE:
		return {"accepted": false, "messages": [63]}
	var first := not delivery_open
	delivery_open = true
	if first:
		fauna.oslo()
	if first and not sos_sent:
		sos_sent = true
		if stoup != null:
			stoup.push(126)
	# YODA151c keeps prior25910; c70/c8e chimes only after first delivery exits.
	pending = {"scene": "oslo", "messages": [91], "departure_chime": first}
	return {"accepted": true, "first": first, "messages": [91]}


func dismiss() -> Dictionary:
	var result := pending.duplicate(true)
	pending = {}
	return result


func choose_whale(proceed: bool) -> Dictionary:
	if pending.get("scene") != "whale_question":
		return {}
	if proceed:
		ending = "death"
		return _event("death", [], {"epitaph": 104}) # YODA0x14b5.
	return dismiss()


func die(reason: int) -> Dictionary:
	if reason < 100 or reason > 105:
		return {}
	ending = "death"
	return _event("death", [], {"epitaph": reason}) # YODA26→27d8.


func snapshot() -> Dictionary:
	return {"version": 1, "urga_key": urga_key, "delivery_open": delivery_open,
		"central_destroyed": central_destroyed, "whale_present": whale_present,
		"sos_sent": sos_sent, "pending": pending.duplicate(true), "ending": ending,
		"spies": spies.duplicate(true), "protection_seen": protection_seen.duplicate(), "hazards": hazards.snapshot(), "fauna": fauna.snapshot()}


func restore(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1:
		return false
	for key in ["urga_key", "delivery_open", "central_destroyed", "whale_present", "sos_sent"]:
		if not value.get(key) is bool:
			return false
	if not value.get("ending") in ["", "sun", "death"] or not value.get("pending") is Dictionary:
		return false
	if not value.get("protection_seen") is Dictionary or not value.protection_seen.get("soleil") is bool or not value.protection_seen.get("viking") is bool:
		return false
	if not value.get("spies") is Array or value.spies.size() != SPY_COUNT:
		return false
	var candidate_hazards = preload("res://scripts/campaign_hazards.gd").new()
	if not candidate_hazards.restore(value.get("hazards")):
		return false
	var candidate_fauna = preload("res://scripts/campaign_fauna.gd").new()
	if value.has("fauna"):
		if not candidate_fauna.restore(value.fauna):
			return false
	elif value.delivery_open:
		candidate_fauna.oslo() # Legacy saves lacked roaming state; known Oslo state.
	var parsed: Array = []
	for record in value.spies:
		if not record is Array or record.size() != SPY_FIELDS:
			return false
		var row: Array = []
		for item in record:
			if not _integer(item):
				return false
			row.append(int(item))
		if row[0] < 0 or row[0] > 3 or row[5] < 0 or row[5] > 2 or row[13] < 0 or row[13] > 199:
			return false
		if row[0] > 1 and (not _in_bounds(Vector2i(row[1] + 40, row[2])) or not _in_bounds(Vector2i(row[3] + 40, row[4]))):
			return false
		parsed.append(row)
	var event: Dictionary = value.pending
	if not event.is_empty():
		if not event.get("scene") in ["wolf", "mole", "slope", "whale_harpoon", "whale_question", "urga", "oslo", "mausoleum", "sun", "sun_end", "earth", "spy_pickup", "sabotage_confirm", "manual_quiz", "death"] or not event.get("messages") is Array:
			return false
		if event.scene in ["wolf", "mole"] and not preload("res://scripts/campaign_ambush_snapshot.gd").valid(event):
			return false
		if event.scene == "manual_quiz" and not preload("res://scripts/manual_quiz.gd").valid(event):
			return false
		if event.scene in ["spy_pickup", "sabotage_confirm"] and (not _integer(event.get("spy")) or event.spy < 0 or event.spy >= SPY_COUNT):
			return false
		if event.get("code_input", false) and (event.scene != "oslo" or not value.urga_key):
			return false
		if event.has("departure_chime") and (event.scene != "oslo" or not value.delivery_open or event.messages.size() != 1 or not _integer(event.messages[0]) or int(event.messages[0]) != 91):
			return false
		for key in ["code_input", "reverse", "departure_chime"]:
			if event.has(key) and not event[key] is bool:
				return false
		for id in event.messages:
			if not _integer(id) or int(id) < 1 or int(id) > 100:
				return false
		if event.has("epitaph") and (not _integer(event.epitaph) or event.epitaph < 100 or event.epitaph > 105):
			return false
	urga_key = value.urga_key
	delivery_open = value.delivery_open
	central_destroyed = value.central_destroyed
	whale_present = value.whale_present
	sos_sent = value.sos_sent
	pending = event.duplicate(true)
	if not pending.is_empty():
		for index in pending.messages.size():
			pending.messages[index] = int(pending.messages[index])
		if pending.has("epitaph"):
			pending.epitaph = int(pending.epitaph)
	ending = value.ending
	spies = parsed
	hazards = candidate_hazards
	fauna = candidate_fauna
	protection_seen = value.protection_seen.duplicate()
	return true


static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(value) and value == floor(value)
