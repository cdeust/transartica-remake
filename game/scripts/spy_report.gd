extends RefCounted

# MIT. Dynamic report TEXTEK0x27f4..2bf0. Historical text loaded privately.
static func format(index: int, spies: Array, enemies, data: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if index < 0 or index >= spies.size():
		return lines
	var record: Array = spies[index]
	var phrases: Dictionary = data.get("report_phrases", {})
	var title: Array = phrases.get(str(0x27fe), [])
	var stamp: Array = phrases.get(str(0x283e), [])
	if title.size() != 3 or stamp.size() != 3:
		return lines
	lines.append(title[0] + str(index + 1) + title[1] + str(record[1] + 40) + title[2] + str(record[2])
		+ stamp[0] + str(record[9]) + stamp[1] + str(record[10]) + stamp[2] + str(record[11]))
	var slot: int = record[7] - 1
	if slot < 0 or slot >= enemies.slots.size():
		return lines
	var enemy: Array = enemies.slots[slot]
	var strength: int = enemy[7] / 20
	lines.append(_phrase(phrases, 0x2a1a if strength < 3 else 0x2a41))
	var level: int = strength % 20
	lines.append(_phrase(phrases, 0x2a73 if level < 7 else 0x2a9c if level < 14 else 0x2ab9))
	# Preserve the original report switch, even though navigation uses keypad codes.
	# cswitch2 adds -1: source values1..8 label SW,S,SE,E,NE,N,NW,W.
	var offsets := [0x2b28, 0x2b43, 0x2b59, 0x2b74, 0x2b89, 0x2ba4, 0x2bba, 0x2bd5]
	if enemy[3] > 0 and enemy[3] <= offsets.size():
		lines.append(_phrase(phrases, 0x2aec) + _phrase(phrases, offsets[enemy[3] - 1]))
	return lines


static func _phrase(phrases: Dictionary, offset: int) -> String:
	var values: Array = phrases.get(str(offset), [])
	return values[0] if not values.is_empty() else ""
