extends RefCounted
class_name SurveyClock

var elapsed_seconds: float = 0.0
var paused: bool = false


func advance(real_delta: float) -> void:
	if real_delta < 0.0:
		return
	if not paused:
		elapsed_seconds += real_delta


func set_elapsed(value: float) -> void:
	elapsed_seconds = maxf(0.0, value)


func display_text() -> String:
	var total_minutes := int(elapsed_seconds / 60.0)
	return "%02d:%02d" % [total_minutes / 60, total_minutes % 60]
