extends RefCounted

# MIT. Original manual controls: SOLEIL0x2b..62, VIKING0x15f..1a1.
const COUNT := 8 # Both scripts rnd(8), despite extra SOLEIL language records.
const ATTEMPTS := 3

static func create(name: String, rng: RandomNumberGenerator, resume: Dictionary) -> Dictionary:
	return {"scene": "manual_quiz", "messages": [54], "quiz": name,
		"index": rng.randi_range(0, COUNT - 1), "attempt": 0, "resume": resume.duplicate(true)}


static func submit(pending: Dictionary, text: String, data: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var records: Array = data.get("quizzes", {}).get(pending.quiz, [])
	if records.size() != COUNT:
		return {"accepted": false, "missing_source": true}
	# Source compares each expected byte until its zero terminator, not input length.
	if text.to_upper().begins_with(records[pending.index].answer):
		return {"accepted": true, "resume": pending.resume.duplicate(true)}
	pending.attempt += 1
	if pending.attempt >= ATTEMPTS:
		return {"accepted": false, "exit": true}
	pending.index = rng.randi_range(0, COUNT - 1)
	return {"accepted": false, "exit": false}


static func lines(pending: Dictionary, data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for line in data.get("messages", {}).get("54", []):
		result.append(line)
	var records: Array = data.get("quizzes", {}).get(pending.quiz, [])
	if result.size() == 4 and records.size() == COUNT:
		var record: Dictionary = records[pending.index]
		# Preserve original labels; insert the numbers in their source positions.
		result[2] = result[2].replace("WORD        OF LINE", "WORD %d OF LINE %d" % [record.word, record.line])
		result[3] = result[3].replace("PAGE    :", "PAGE %d :" % record.page)
	return result


static func valid(event: Dictionary) -> bool:
	if not event.get("quiz") in ["soleil", "viking"] or not event.get("resume") is Dictionary:
		return false
	var resume: Dictionary = event.resume
	if resume.has("city"):
		if not resume.city is int and not resume.city is float:
			return false
		if not is_finite(resume.city) or resume.city != floor(resume.city) or not int(resume.city) in [5, 6, 7, 8, 9, 12]:
			return false
	elif resume.get("scene") != "oslo" or not resume.get("code_input", false) or not resume.get("quiz_done", false) or resume.get("messages", []).size() != 1 or resume.messages[0] != 90:
		return false
	for key in ["index", "attempt"]:
		if not event.get(key) is int and not event.get(key) is float:
			return false
		if not is_finite(event[key]) or event[key] != floor(event[key]):
			return false
	return event.index >= 0 and event.index < COUNT and event.attempt >= 0 and event.attempt < ATTEMPTS
