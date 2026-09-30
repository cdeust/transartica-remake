extends RefCounted

# MIT. Authored persistence schema; validates before any session mutation.
const State = preload("res://scripts/campaign_state.gd")


# Pure validation is deliberately usable before app/network mutation.
static func validate(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1 or not State._integer(value.get("page")) or value.page < 0:
		return false
	if not value.get("selection") in ["", "send", "dynamite"] or not value.get("crew_menu") in ["", "spies", "cars", "car_direction"]:
		return false
	if not value.get("notice") is bool or not value.get("car_missile") is bool or not value.get("return_room") in ["boudoir", "quarters", "city"]:
		return false
	var candidate = State.new()
	if not candidate.restore(value.get("state")) or value.page > candidate.pending.get("messages", []).size():
		return false
	var presentation: Variant = value.get("presentation")
	if not presentation is Dictionary:
		return false
	for key in ["visible", "entering_code", "question"]:
		if not presentation.get(key) is bool:
			return false
	if not presentation.get("scene") is String or not presentation.get("input_code") is String:
		return false
	if presentation.input_code.length() > 5 or (not presentation.input_code.is_empty() and not presentation.input_code.is_valid_int()):
		return false
	for key in ["lines", "menu"]:
		if not presentation.get(key) is Array:
			return false
		for line in presentation[key]:
			if not line is String:
				return false
	return true
