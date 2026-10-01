extends RefCounted

# MIT. Atomic stage records prevent repeat loss on interrupted presentation.
static func valid(event: Dictionary) -> bool:
	if not preload("res://scripts/campaign_fauna.gd")._integer(event.get("divisor")) or event.divisor < 2 or event.divisor > 10:
		return false
	if not preload("res://scripts/campaign_fauna.gd")._integer(event.get("applied")) or event.applied < 0 or event.applied > 2:
		return false
	if not event.messages is Array or event.messages.size() != 3 or not event.get("ambush_lines") is Array:
		return false
	var expected := [77, 81, 79] if event.scene == "wolf" else [78, 81, 80]
	for index in 3:
		if not preload("res://scripts/campaign_fauna.gd")._integer(event.messages[index]) or int(event.messages[index]) != expected[index]:
			return false
	for line in event.ambush_lines:
		if not line is String:
			return false
	return true
