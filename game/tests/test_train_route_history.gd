extends "res://tests/test_travel_regressions.gd"
# MIT. The exact committed source can be compiled in memory for red-before
# evidence without reverting the shared checkout or modifying another agent.
func _run() -> void:
	if "--baseline" in OS.get_cmdline_user_args():
		var source := FileAccess.get_file_as_string("res://../.cache/travel-baseline.gd")
		var baseline := GDScript.new()
		baseline.source_code = source.replace("class_name TrainJourney","")
		assert(baseline.reload() == OK,"committed baseline compiles")
		journey_script = baseline
	_test_backing_history()
	_test_live_switch_after_reversal()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: backing past seed boundary, current switch after reverser round trip, route persistence")
	quit(0 if failures.is_empty() else 1)
