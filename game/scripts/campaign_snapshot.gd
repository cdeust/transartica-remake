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
	if not presentation.get("scene") in ["", "crew", "urga", "oslo", "mausoleum", "sun", "sun-restored", "slope", "whale_question", "whale_harpoon", "spy_pickup", "sabotage_confirm", "death", "earth", "report"] or not presentation.get("input_code") is String:
		return false
	if presentation.input_code.length() > 5:
		return false
	for digit in presentation.input_code:
		if digit.unicode_at(0) < 48 or digit.unicode_at(0) > 57:
			return false
	if not candidate.pending.is_empty():
		var expected: String = candidate.pending.scene
		if expected == "sun_end":
			expected = "sun-restored"
		if not presentation.visible or presentation.scene != expected or value.notice:
			return false
	if not presentation.input_code.is_empty() and not presentation.entering_code:
		return false
	if presentation.entering_code and (candidate.pending.get("scene") != "oslo" or not candidate.pending.get("code_input", false)):
		return false
	if presentation.question != (candidate.pending.get("scene") in ["whale_question", "spy_pickup", "sabotage_confirm"]):
		return false
	for key in ["lines", "menu"]:
		if not presentation.get(key) is Array:
			return false
		for line in presentation[key]:
			if not line is String:
				return false
	return true
