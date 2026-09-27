extends RefCounted

# Original game calendar: main+0x2fb0 minutes, +0x2fad hour, +0x2fb2 day.
# TABLE 0x0130..0x013c starts at day 1, 00:00. YODA 0x3394 adds the clock factor
# main+0x2fb8 (1 normal, 3 fast) to the minutes each time it hands TIME that many
# phases, so one game minute is one TIME phase; a remake cycle is three phases
# (tasks/evidence/engine-cadence.md, navigation-playable.md).
const MINUTES_PER_CYCLE := 3
const NORMAL_FACTOR := 1 # YODA 0x3d8
const FAST_FACTOR := 3 # YODA/TEXTEK branches that set main+0x2fb8 = 3
# YODA 0x33ba..0x33f8: the (110,33) bridge opens at 12:00 (-121) and closes at 14:00 (-120).
const TIMED_BRIDGE := Vector2i(110, 33)
const BRIDGE_OPEN_HOUR := 12
const BRIDGE_CLOSED_HOUR := 14
const BRIDGE_OPEN := -121
const BRIDGE_CLOSED := -120

var minute := 0
var hour := 0
var day := 1
var factor := NORMAL_FACTOR


# Advances one remake cycle; returns the hour hooks reached, oldest first.
# Hooks not yet ported (enemy spawn 0x2af7, day handlers 0x2f59/0x300e/0x2fc3,
# mines 0x1e2a) are reported by name so callers can see them.
func advance_cycle() -> Array[String]:
	var events: Array[String] = []
	# One YODA trigger adds `factor` minutes and runs that many phases; the fast clock
	# changes how many cycles pass per real second, not the minutes in a cycle.
	for trigger in MINUTES_PER_CYCLE / factor:
		minute += factor
		if minute > 59:
			minute %= 60
			_next_hour(events)
	return events


func _next_hour(events: Array[String]) -> void:
	hour += 1
	if hour == BRIDGE_OPEN_HOUR:
		events.append("bridge_open")
	elif hour == BRIDGE_CLOSED_HOUR:
		events.append("bridge_closed")
	if hour > 23:
		day += 1
		hour = 0
		events.append("new_day")
		if day % 3 == 0:
			events.append("mines")


func bridge_code() -> int:
	return BRIDGE_OPEN if hour >= BRIDGE_OPEN_HOUR and hour < BRIDGE_CLOSED_HOUR else BRIDGE_CLOSED


func display_text() -> String:
	return "DAY %d %02d:%02d" % [day, hour, minute]


func snapshot() -> Dictionary:
	return {"minute": minute, "hour": hour, "day": day, "factor": factor}


func restore(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for key in ["minute", "hour", "day", "factor"]:
		if not data.has(key) or not typeof(data[key]) in [TYPE_INT, TYPE_FLOAT]:
			return false
	if int(data.minute) < 0 or int(data.minute) > 59 or int(data.hour) < 0 or int(data.hour) > 23 \
			or int(data.day) < 1 or not int(data.factor) in [NORMAL_FACTOR, FAST_FACTOR]:
		return false
	minute = int(data.minute)
	hour = int(data.hour)
	day = int(data.day)
	factor = int(data.factor)
	return true
